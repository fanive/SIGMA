from __future__ import annotations

import argparse
import logging
from pathlib import Path

from .collector import YFinanceCollector
from .config import (
    DB_PATH,
    DEFAULT_HISTORY_INTERVAL,
    DEFAULT_HISTORY_PERIOD,
    DEFAULT_SCHEDULE_MINUTES,
    WATCHLIST_PATH,
)
from .db import Database
from .scheduler import run_scheduler


def configure_logging(verbose: bool) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )


def parse_symbols(symbols_arg: str | None, symbols_file: str | None) -> list[str]:
    if symbols_arg:
        symbols = [item.strip().upper() for item in symbols_arg.split(",") if item.strip()]
        if symbols:
            return symbols

    file_path = Path(symbols_file) if symbols_file else WATCHLIST_PATH
    if not file_path.exists():
        raise FileNotFoundError(f"Symbols file not found: {file_path}")

    symbols = [line.strip().upper() for line in file_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not symbols:
        raise ValueError("No symbols found. Add symbols in watchlist.txt or pass --symbols")
    return symbols


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SIGMA yfinance collector (no FastAPI)")
    parser.add_argument("--db-path", default=str(DB_PATH), help="SQLite database path")
    parser.add_argument("--verbose", action="store_true", help="Enable debug logs")

    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("init", help="Initialize database schema")

    once = sub.add_parser("once", help="Run one collection pass")
    once.add_argument("--symbols", help="Comma-separated symbols, e.g. AAPL,MSFT,NVDA")
    once.add_argument("--symbols-file", default=str(WATCHLIST_PATH), help="Path to symbols file")
    once.add_argument("--history-period", default=DEFAULT_HISTORY_PERIOD)
    once.add_argument("--history-interval", default=DEFAULT_HISTORY_INTERVAL)

    sched = sub.add_parser("schedule", help="Run recurring collection")
    sched.add_argument("--symbols", help="Comma-separated symbols, e.g. AAPL,MSFT,NVDA")
    sched.add_argument("--symbols-file", default=str(WATCHLIST_PATH), help="Path to symbols file")
    sched.add_argument("--history-period", default=DEFAULT_HISTORY_PERIOD)
    sched.add_argument("--history-interval", default=DEFAULT_HISTORY_INTERVAL)
    sched.add_argument("--interval-minutes", type=int, default=DEFAULT_SCHEDULE_MINUTES)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    configure_logging(args.verbose)

    db = Database(Path(args.db_path))
    collector = YFinanceCollector(db=db)

    if args.command == "init":
        db.init_schema()
        logging.getLogger(__name__).info("Database initialized at %s", args.db_path)
        return

    symbols = parse_symbols(getattr(args, "symbols", None), getattr(args, "symbols_file", None))

    db.init_schema()

    if args.command == "once":
        collector.collect_symbols(symbols, history_period=args.history_period, history_interval=args.history_interval)
        logging.getLogger(__name__).info("Collection completed for %s symbols", len(symbols))
        return

    run_scheduler(
        collector=collector,
        symbols=symbols,
        history_period=args.history_period,
        history_interval=args.history_interval,
        interval_minutes=args.interval_minutes,
    )
