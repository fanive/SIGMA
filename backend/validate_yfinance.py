from __future__ import annotations

import argparse
import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from yf_core.collector import YFinanceCollector
from yf_core.config import DB_PATH, DEFAULT_HISTORY_INTERVAL, DEFAULT_HISTORY_PERIOD, WATCHLIST_PATH
from yf_core.db import Database


@dataclass
class SymbolReport:
    symbol: str
    quote_ok: bool
    history_ok: bool
    fundamentals_ok: bool
    options_ok: bool
    news_ok: bool
    details: dict

    @property
    def score(self) -> int:
        checks = [self.quote_ok, self.history_ok, self.fundamentals_ok, self.options_ok, self.news_ok]
        return int((sum(1 for c in checks if c) / len(checks)) * 100)


def parse_symbols(symbols_arg: str | None, symbols_file: str | None) -> list[str]:
    if symbols_arg:
        out = [item.strip().upper() for item in symbols_arg.split(",") if item.strip()]
        if out:
            return out
    file_path = Path(symbols_file) if symbols_file else WATCHLIST_PATH
    if not file_path.exists():
        raise FileNotFoundError(f"Symbols file not found: {file_path}")
    symbols = [line.strip().upper() for line in file_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not symbols:
        raise ValueError("No symbols found")
    return symbols


def _latest_json(conn: sqlite3.Connection, table: str, symbol: str, json_col: str = "payload_json") -> dict:
    order_clause = "as_of DESC"
    if table != "quotes":
        order_clause = "as_of DESC, id DESC"

    row = conn.execute(
        f"SELECT {json_col} FROM {table} WHERE symbol = ? ORDER BY {order_clause} LIMIT 1",  # noqa: S608
        (symbol,),
    ).fetchone()
    if not row:
        return {}
    try:
        return json.loads(row[0]) if row[0] else {}
    except json.JSONDecodeError:
        return {}


def _history_count(conn: sqlite3.Connection, symbol: str, interval: str) -> int:
    row = conn.execute(
        "SELECT COUNT(*) FROM ohlcv WHERE symbol = ? AND interval = ?",
        (symbol, interval),
    ).fetchone()
    return int(row[0]) if row else 0


def _news_count(conn: sqlite3.Connection, symbol: str) -> int:
    row = conn.execute(
        "SELECT COUNT(*) FROM news_snapshots WHERE symbol = ?",
        (symbol,),
    ).fetchone()
    return int(row[0]) if row else 0


def _options_latest_counts(conn: sqlite3.Connection, symbol: str) -> tuple[int, int]:
    row = conn.execute(
        "SELECT calls_json, puts_json FROM options_snapshots WHERE symbol = ? ORDER BY as_of DESC, id DESC LIMIT 1",
        (symbol,),
    ).fetchone()
    if not row:
        return (0, 0)
    try:
        calls = json.loads(row[0]) if row[0] else []
        puts = json.loads(row[1]) if row[1] else []
    except json.JSONDecodeError:
        return (0, 0)
    return (len(calls), len(puts))


def validate_symbol(conn: sqlite3.Connection, symbol: str, interval: str) -> SymbolReport:
    quote = _latest_json(conn, "quotes", symbol)
    fundamentals = _latest_json(conn, "fundamentals_snapshots", symbol)

    history_rows = _history_count(conn, symbol, interval)
    news_rows = _news_count(conn, symbol)
    calls_count, puts_count = _options_latest_counts(conn, symbol)

    quote_ok = bool(quote and (quote.get("price") or 0) > 0)
    history_ok = history_rows > 0

    info = fundamentals.get("info", {}) if isinstance(fundamentals, dict) else {}
    inc = fundamentals.get("income_stmt", []) if isinstance(fundamentals, dict) else []
    bs = fundamentals.get("balance_sheet", []) if isinstance(fundamentals, dict) else []
    cf = fundamentals.get("cashflow", []) if isinstance(fundamentals, dict) else []
    fundamentals_ok = bool(info) and (len(inc) > 0 or len(bs) > 0 or len(cf) > 0)

    # Some tickers legitimately have no options or sparse news.
    options_ok = (calls_count + puts_count) > 0
    news_ok = news_rows > 0

    return SymbolReport(
        symbol=symbol,
        quote_ok=quote_ok,
        history_ok=history_ok,
        fundamentals_ok=fundamentals_ok,
        options_ok=options_ok,
        news_ok=news_ok,
        details={
            "price": quote.get("price"),
            "historyRows": history_rows,
            "incomePeriods": len(inc),
            "balancePeriods": len(bs),
            "cashflowPeriods": len(cf),
            "optionsCalls": calls_count,
            "optionsPuts": puts_count,
            "newsRows": news_rows,
        },
    )


def print_report(reports: Iterable[SymbolReport]) -> None:
    reports = list(reports)
    print("\nYFINANCE VALIDATION REPORT")
    print("=" * 70)
    total_scores = 0
    for r in reports:
        total_scores += r.score
        print(
            f"{r.symbol:8} | score={r.score:3}% | quote={r.quote_ok} history={r.history_ok} "
            f"fundamentals={r.fundamentals_ok} options={r.options_ok} news={r.news_ok}"
        )
        print(
            f"          price={r.details['price']} historyRows={r.details['historyRows']} "
            f"inc={r.details['incomePeriods']} bs={r.details['balancePeriods']} cf={r.details['cashflowPeriods']} "
            f"calls={r.details['optionsCalls']} puts={r.details['optionsPuts']} news={r.details['newsRows']}"
        )

    avg = int(total_scores / len(reports)) if reports else 0
    print("-" * 70)
    print(f"GLOBAL SCORE: {avg}%")
    print("Rule of thumb: >=80% is healthy. <80% means some categories are missing or blocked.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate yfinance data completeness for SIGMA")
    parser.add_argument("--db-path", default=str(DB_PATH), help="SQLite database path")
    parser.add_argument("--symbols", help="Comma-separated symbols, e.g. AAPL,MSFT,NVDA")
    parser.add_argument("--symbols-file", default=str(WATCHLIST_PATH), help="Path to watchlist file")
    parser.add_argument("--history-period", default=DEFAULT_HISTORY_PERIOD)
    parser.add_argument("--history-interval", default=DEFAULT_HISTORY_INTERVAL)
    parser.add_argument(
        "--skip-collect",
        action="store_true",
        help="Do not fetch new data, only validate what is already in DB",
    )

    args = parser.parse_args()

    symbols = parse_symbols(args.symbols, args.symbols_file)

    db = Database(Path(args.db_path))
    db.init_schema()

    if not args.skip_collect:
        collector = YFinanceCollector(db=db)
        collector.collect_symbols(symbols, history_period=args.history_period, history_interval=args.history_interval)

    with db.connect() as conn:
        reports = [validate_symbol(conn, symbol, args.history_interval) for symbol in symbols]

    print_report(reports)


if __name__ == "__main__":
    main()
