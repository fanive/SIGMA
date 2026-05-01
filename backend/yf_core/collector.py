from __future__ import annotations

import logging
import time
from datetime import datetime
from typing import Iterable

import pandas as pd
import yfinance as yf

from .db import Database
from .utils import safe_float, safe_json_value

LOGGER = logging.getLogger(__name__)


class YFinanceCollector:
    def __init__(self, db: Database, max_retries: int = 3, retry_delay_seconds: float = 1.0):
        self.db = db
        self.max_retries = max_retries
        self.retry_delay_seconds = retry_delay_seconds

    def _with_retry(self, fn, *args, **kwargs):
        last_error = None
        for attempt in range(1, self.max_retries + 1):
            try:
                return fn(*args, **kwargs)
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                LOGGER.warning("Attempt %s/%s failed: %s", attempt, self.max_retries, exc)
                if attempt < self.max_retries:
                    time.sleep(self.retry_delay_seconds * attempt)
        raise RuntimeError(f"Operation failed after {self.max_retries} retries") from last_error

    def collect_symbols(self, symbols: Iterable[str], history_period: str, history_interval: str) -> None:
        for raw_symbol in symbols:
            symbol = raw_symbol.strip().upper()
            if not symbol:
                continue
            try:
                self.collect_symbol(symbol, history_period, history_interval)
                LOGGER.info("Collected %s successfully", symbol)
            except Exception as exc:  # noqa: BLE001
                LOGGER.exception("Failed collecting %s: %s", symbol, exc)

    def collect_symbol(self, symbol: str, history_period: str, history_interval: str) -> None:
        ticker = yf.Ticker(symbol)

        info = self._with_retry(lambda: ticker.info or {})
        fast_info = self._with_retry(lambda: dict(ticker.fast_info) if ticker.fast_info else {})

        quote_payload = self._build_quote_payload(symbol, info, fast_info)
        self.db.upsert_quote(symbol, quote_payload)

        history = self._with_retry(ticker.history, period=history_period, interval=history_interval)
        history_rows = self._history_to_rows(history)
        self.db.upsert_ohlcv_rows(symbol, history_interval, history_rows)

        fundamentals_payload = {
            "info": safe_json_value(info),
            "income_stmt": self._financial_df_to_dict(self._with_retry(lambda: ticker.income_stmt)),
            "balance_sheet": self._financial_df_to_dict(self._with_retry(lambda: ticker.balance_sheet)),
            "cashflow": self._financial_df_to_dict(self._with_retry(lambda: ticker.cashflow)),
            "collectedAt": datetime.utcnow().isoformat(),
        }
        self.db.insert_fundamentals_snapshot(symbol, "yfinance", fundamentals_payload)

        options_exps = self._with_retry(lambda: list(ticker.options) if ticker.options else [])
        if options_exps:
            selected_exp = options_exps[0]
            option_chain = self._with_retry(ticker.option_chain, selected_exp)
            calls = self._df_to_records(option_chain.calls)
            puts = self._df_to_records(option_chain.puts)
            self.db.insert_options_snapshot(symbol, selected_exp, calls, puts)

        news_items = self._with_retry(lambda: ticker.news or [])
        normalized_news = [
            {
                "title": item.get("title"),
                "publisher": item.get("publisher"),
                "link": item.get("link"),
                "providerPublishTime": item.get("providerPublishTime"),
                "type": item.get("type", "STORY"),
            }
            for item in news_items[:15]
        ]
        self.db.replace_latest_news(symbol, normalized_news)

    def _build_quote_payload(self, symbol: str, info: dict, fast_info: dict) -> dict:
        price = safe_float(info.get("currentPrice") or info.get("regularMarketPrice") or fast_info.get("lastPrice"))
        prev = safe_float(info.get("previousClose") or info.get("regularMarketPreviousClose") or fast_info.get("previousClose"))
        change = price - prev if prev > 0 else 0.0
        change_pct = (change / prev) * 100 if prev > 0 else 0.0

        return {
            "symbol": symbol,
            "shortName": info.get("shortName") or symbol,
            "longName": info.get("longName") or info.get("shortName") or symbol,
            "price": round(price, 6),
            "previousClose": round(prev, 6),
            "change": round(change, 6),
            "changePercent": round(change_pct, 6),
            "volume": safe_float(info.get("volume") or info.get("regularMarketVolume") or fast_info.get("lastVolume")),
            "marketCap": safe_float(info.get("marketCap") or fast_info.get("marketCap")),
            "currency": info.get("currency") or "USD",
            "exchange": info.get("exchange") or info.get("fullExchangeName") or "",
            "quoteType": info.get("quoteType") or "",
            "collectedAt": datetime.utcnow().isoformat(),
        }

    def _history_to_rows(self, history: pd.DataFrame) -> list[dict]:
        if history is None or history.empty:
            return []
        rows = []
        for dt, row in history.iterrows():
            ts = dt.tz_localize(None).isoformat() if hasattr(dt, "tz") and dt.tz else dt.isoformat()
            close_value = row.get("Close")
            if close_value is None or pd.isna(close_value):
                continue
            rows.append(
                {
                    "ts": ts,
                    "open": safe_float(row.get("Open"), default=0.0),
                    "high": safe_float(row.get("High"), default=0.0),
                    "low": safe_float(row.get("Low"), default=0.0),
                    "close": safe_float(close_value, default=0.0),
                    "volume": safe_float(row.get("Volume"), default=0.0),
                }
            )
        return rows

    def _df_to_records(self, df: pd.DataFrame) -> list[dict]:
        if df is None or df.empty:
            return []
        output = df.copy()
        if isinstance(output.index, pd.DatetimeIndex):
            output = output.reset_index()
        for col in output.columns:
            if pd.api.types.is_datetime64_any_dtype(output[col]):
                output[col] = output[col].astype(str)
        output = output.where(pd.notnull(output), None)
        return [safe_json_value(item) for item in output.to_dict(orient="records")]

    def _financial_df_to_dict(self, df: pd.DataFrame) -> list[dict]:
        if df is None or df.empty:
            return []
        rows = []
        for col in df.columns:
            period = str(col.date()) if hasattr(col, "date") else str(col)
            values = {str(idx): safe_json_value(df.loc[idx, col]) for idx in df.index}
            rows.append({"period": period, **values})
        return rows
