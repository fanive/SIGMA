from __future__ import annotations

import json
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Iterable


class Database:
    def __init__(self, db_path: Path):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA foreign_keys=ON;")
        return conn

    def init_schema(self) -> None:
        with self.connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS quotes (
                    symbol TEXT PRIMARY KEY,
                    as_of TEXT NOT NULL,
                    price REAL,
                    previous_close REAL,
                    change_value REAL,
                    change_percent REAL,
                    volume REAL,
                    market_cap REAL,
                    currency TEXT,
                    exchange_name TEXT,
                    payload_json TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS ohlcv (
                    symbol TEXT NOT NULL,
                    interval TEXT NOT NULL,
                    ts TEXT NOT NULL,
                    open REAL,
                    high REAL,
                    low REAL,
                    close REAL,
                    volume REAL,
                    PRIMARY KEY(symbol, interval, ts)
                );

                CREATE TABLE IF NOT EXISTS fundamentals_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    symbol TEXT NOT NULL,
                    as_of TEXT NOT NULL,
                    source TEXT NOT NULL,
                    payload_json TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS options_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    symbol TEXT NOT NULL,
                    expiration TEXT NOT NULL,
                    as_of TEXT NOT NULL,
                    calls_json TEXT NOT NULL,
                    puts_json TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS news_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    symbol TEXT NOT NULL,
                    as_of TEXT NOT NULL,
                    title TEXT,
                    publisher TEXT,
                    link TEXT,
                    published_ts INTEGER,
                    article_type TEXT,
                    payload_json TEXT NOT NULL
                );

                CREATE INDEX IF NOT EXISTS idx_ohlcv_symbol_ts ON ohlcv(symbol, ts);
                CREATE INDEX IF NOT EXISTS idx_fund_symbol_asof ON fundamentals_snapshots(symbol, as_of);
                CREATE INDEX IF NOT EXISTS idx_opt_symbol_asof ON options_snapshots(symbol, as_of);
                CREATE INDEX IF NOT EXISTS idx_news_symbol_asof ON news_snapshots(symbol, as_of);
                """
            )

    def upsert_quote(self, symbol: str, payload: dict) -> None:
        now = datetime.utcnow().isoformat()
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO quotes (
                    symbol, as_of, price, previous_close, change_value, change_percent,
                    volume, market_cap, currency, exchange_name, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(symbol) DO UPDATE SET
                    as_of=excluded.as_of,
                    price=excluded.price,
                    previous_close=excluded.previous_close,
                    change_value=excluded.change_value,
                    change_percent=excluded.change_percent,
                    volume=excluded.volume,
                    market_cap=excluded.market_cap,
                    currency=excluded.currency,
                    exchange_name=excluded.exchange_name,
                    payload_json=excluded.payload_json
                """,
                (
                    symbol,
                    now,
                    payload.get("price"),
                    payload.get("previousClose"),
                    payload.get("change"),
                    payload.get("changePercent"),
                    payload.get("volume"),
                    payload.get("marketCap"),
                    payload.get("currency"),
                    payload.get("exchange"),
                    json.dumps(payload, ensure_ascii=True),
                ),
            )

    def upsert_ohlcv_rows(self, symbol: str, interval: str, rows: Iterable[dict]) -> None:
        rows = list(rows)
        if not rows:
            return
        with self.connect() as conn:
            conn.executemany(
                """
                INSERT INTO ohlcv(symbol, interval, ts, open, high, low, close, volume)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(symbol, interval, ts) DO UPDATE SET
                    open=excluded.open,
                    high=excluded.high,
                    low=excluded.low,
                    close=excluded.close,
                    volume=excluded.volume
                """,
                [
                    (
                        symbol,
                        interval,
                        row["ts"],
                        row.get("open"),
                        row.get("high"),
                        row.get("low"),
                        row.get("close"),
                        row.get("volume"),
                    )
                    for row in rows
                ],
            )

    def insert_fundamentals_snapshot(self, symbol: str, source: str, payload: dict) -> None:
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO fundamentals_snapshots(symbol, as_of, source, payload_json)
                VALUES (?, ?, ?, ?)
                """,
                (
                    symbol,
                    datetime.utcnow().isoformat(),
                    source,
                    json.dumps(payload, ensure_ascii=True),
                ),
            )

    def insert_options_snapshot(self, symbol: str, expiration: str, calls: list[dict], puts: list[dict]) -> None:
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO options_snapshots(symbol, expiration, as_of, calls_json, puts_json)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    symbol,
                    expiration,
                    datetime.utcnow().isoformat(),
                    json.dumps(calls, ensure_ascii=True),
                    json.dumps(puts, ensure_ascii=True),
                ),
            )

    def replace_latest_news(self, symbol: str, articles: list[dict]) -> None:
        now = datetime.utcnow().isoformat()
        with self.connect() as conn:
            conn.execute(
                "DELETE FROM news_snapshots WHERE symbol = ? AND as_of < ?",
                (symbol, now),
            )
            conn.executemany(
                """
                INSERT INTO news_snapshots(
                    symbol, as_of, title, publisher, link, published_ts, article_type, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        symbol,
                        now,
                        item.get("title"),
                        item.get("publisher"),
                        item.get("link"),
                        item.get("providerPublishTime"),
                        item.get("type"),
                        json.dumps(item, ensure_ascii=True),
                    )
                    for item in articles
                ],
            )
