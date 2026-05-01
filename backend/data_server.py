from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import pandas as pd
import yfinance as yf
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="SIGMA Local yfinance Gateway", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _num(val, default=0.0):
    if val is None:
        return default
    try:
        f = float(val)
        return default if pd.isna(f) else f
    except (TypeError, ValueError):
        return default


def _normalize_value(value: Any):
    if value is None:
        return None
    if isinstance(value, (str, bool, int, float)):
        if isinstance(value, float) and pd.isna(value):
            return None
        return value
    if isinstance(value, (pd.Timestamp, datetime)):
        return value.isoformat()
    try:
        if pd.isna(value):
            return None
    except Exception:
        pass
    return str(value)


def _df_to_rows(df: Any, limit: int = 200):
    if df is None or not isinstance(df, pd.DataFrame) or df.empty:
        return []
    framed = df.copy().reset_index()
    rows = []
    for _, row in framed.head(limit).iterrows():
        rows.append({k: _normalize_value(v) for k, v in row.to_dict().items()})
    return rows


def _series_to_rows(series: Any, key: str = "value", limit: int = 500):
    if series is None or not isinstance(series, pd.Series) or series.empty:
        return []
    rows = []
    for idx, val in series.head(limit).items():
        rows.append({"date": _normalize_value(idx), key: _normalize_value(val)})
    return rows


def _statement_to_rows(df: Any, limit: int = 8):
    if df is None or not isinstance(df, pd.DataFrame) or df.empty:
        return []
    transposed = df.T.reset_index().rename(columns={"index": "asOfDate"})
    rows = []
    for _, row in transposed.head(limit).iterrows():
        rows.append({k: _normalize_value(v) for k, v in row.to_dict().items()})
    return rows


def _sanitize_dict(data: Any):
    if isinstance(data, dict):
        return {str(k): _sanitize_dict(v) for k, v in data.items()}
    if isinstance(data, list):
        return [_sanitize_dict(v) for v in data]
    if isinstance(data, pd.DataFrame):
        return _df_to_rows(data)
    if isinstance(data, pd.Series):
        return _series_to_rows(data)
    return _normalize_value(data)


@app.get("/")
async def health():
    return {
        "status": "ok",
        "service": "yfinance-gateway",
        "time": datetime.now(timezone.utc).isoformat(),
        "note": "Yahoo Finance data may be delayed and is not exchange-tick realtime.",
    }


@app.get("/search")
async def search_tickers(q: str = Query(..., min_length=1)):
    try:
        s = yf.Search(q)
        quotes = s.quotes or []
        out = []
        for item in quotes[:20]:
            sym = (item.get("symbol") or "").upper()
            if not sym:
                continue
            out.append(
                {
                    "symbol": sym,
                    "name": item.get("shortname") or item.get("longname") or sym,
                    "stockExchange": item.get("exchange") or "",
                    "exchangeShortName": item.get("exchange") or "",
                    "type": item.get("quoteType") or "EQUITY",
                }
            )
        return out
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"search failed: {e}")


@app.get("/quote/{symbol}")
async def quote(symbol: str):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        info = t.info or {}
        fi = t.fast_info
        price = _num(info.get("currentPrice") or info.get("regularMarketPrice") or (fi.get("lastPrice") if fi else 0))
        prev = _num(info.get("previousClose") or info.get("regularMarketPreviousClose") or (fi.get("previousClose") if fi else 0))
        change = price - prev if prev > 0 else 0
        change_pct = (change / prev * 100) if prev > 0 else 0
        return {
            "symbol": sym,
            "name": info.get("shortName") or info.get("longName") or sym,
            "price": price,
            "change": change,
            "changesPercentage": change_pct,
            "changePercent": change_pct,
            "volume": _num(info.get("volume") or info.get("regularMarketVolume")),
            "avgVolume": _num(info.get("averageVolume")),
            "marketCap": _num(info.get("marketCap")),
            "exchange": info.get("exchange") or info.get("fullExchangeName") or "",
            "currency": info.get("currency") or "USD",
            "marketState": info.get("marketState") or "UNKNOWN",
            "open": _num(info.get("open") or info.get("regularMarketOpen")),
            "dayHigh": _num(info.get("dayHigh") or info.get("regularMarketDayHigh")),
            "dayLow": _num(info.get("dayLow") or info.get("regularMarketDayLow")),
            "fiftyTwoWeekHigh": _num(info.get("fiftyTwoWeekHigh")),
            "fiftyTwoWeekLow": _num(info.get("fiftyTwoWeekLow")),
            "previousClose": prev,
            "preMarketPrice": _num(info.get("preMarketPrice")),
            "postMarketPrice": _num(info.get("postMarketPrice")),
            "regularMarketTime": _normalize_value(info.get("regularMarketTime")),
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"quote failed for {sym}: {e}")


@app.get("/multi-quote")
async def multi_quote(symbols: str = Query(..., description="Comma separated symbols")):
    sym_list = [s.strip().upper() for s in symbols.split(",") if s.strip()]
    out = []
    for sym in sym_list[:50]:
        try:
            out.append(await quote(sym))
        except Exception:
            continue
    return out


@app.get("/history/{symbol}")
async def history(symbol: str, range: str = "1mo", interval: str = "1d", prepost: bool = False):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        hist = t.history(period=range, interval=interval, prepost=prepost, auto_adjust=False)
        if hist.empty:
            return []
        rows = []
        for dt, row in hist.iterrows():
            if hasattr(dt, "tz") and dt.tz:
                dt = dt.tz_localize(None)
            close_val = row.get("Close")
            if close_val is None or pd.isna(close_val):
                continue
            rows.append(
                {
                    "date": dt.isoformat(),
                    "open": float(row.get("Open", 0)) if not pd.isna(row.get("Open", 0)) else None,
                    "high": float(row.get("High", 0)) if not pd.isna(row.get("High", 0)) else None,
                    "low": float(row.get("Low", 0)) if not pd.isna(row.get("Low", 0)) else None,
                    "close": float(close_val),
                    "volume": float(row.get("Volume", 0)) if not pd.isna(row.get("Volume", 0)) else 0,
                }
            )
        return rows
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"history failed for {sym}: {e}")


@app.get("/intraday/{symbol}")
async def intraday(symbol: str, interval: str = "1m", range: str = "1d", prepost: bool = True):
    """Intraday bars. Note: 1m data is usually limited to recent days by Yahoo."""
    return await history(symbol=symbol, range=range, interval=interval, prepost=prepost)


@app.get("/profile/{symbol}")
async def profile(symbol: str):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        info = t.info or {}
        return {
            "symbol": sym,
            "shortName": info.get("shortName"),
            "longName": info.get("longName"),
            "sector": info.get("sector"),
            "industry": info.get("industry"),
            "country": info.get("country"),
            "website": info.get("website"),
            "fullTimeEmployees": _normalize_value(info.get("fullTimeEmployees")),
            "longBusinessSummary": info.get("longBusinessSummary"),
            "beta": _num(info.get("beta"), default=None),
            "trailingPE": _num(info.get("trailingPE"), default=None),
            "forwardPE": _num(info.get("forwardPE"), default=None),
            "dividendYield": _num(info.get("dividendYield"), default=None),
            "marketCap": _num(info.get("marketCap"), default=None),
            "sharesOutstanding": _num(info.get("sharesOutstanding"), default=None),
            "enterpriseValue": _num(info.get("enterpriseValue"), default=None),
            "currency": info.get("currency"),
            "exchange": info.get("exchange") or info.get("fullExchangeName"),
            "quoteType": info.get("quoteType"),
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"profile failed for {sym}: {e}")


@app.get("/financials/{symbol}")
async def financials(symbol: str, quarterly: bool = True, limit: int = 8):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        income_df = t.quarterly_income_stmt if quarterly else t.income_stmt
        balance_df = t.quarterly_balance_sheet if quarterly else t.balance_sheet
        cashflow_df = t.quarterly_cashflow if quarterly else t.cashflow
        return {
            "symbol": sym,
            "frequency": "quarterly" if quarterly else "annual",
            "incomeStatement": _statement_to_rows(income_df, limit=limit),
            "balanceSheet": _statement_to_rows(balance_df, limit=limit),
            "cashFlow": _statement_to_rows(cashflow_df, limit=limit),
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"financials failed for {sym}: {e}")


@app.get("/analysis/{symbol}")
async def analysis(symbol: str, limit: int = 100):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        return {
            "symbol": sym,
            "analystPriceTargets": _sanitize_dict(t.analyst_price_targets),
            "recommendations": _df_to_rows(t.recommendations, limit=limit),
            "upgradesDowngrades": _df_to_rows(t.upgrades_downgrades, limit=limit),
            "earningsEstimate": _df_to_rows(t.earnings_estimate, limit=limit),
            "revenueEstimate": _df_to_rows(t.revenue_estimate, limit=limit),
            "epsTrend": _df_to_rows(t.eps_trend, limit=limit),
            "epsRevisions": _df_to_rows(t.eps_revisions, limit=limit),
            "growthEstimates": _df_to_rows(t.growth_estimates, limit=limit),
            "earningsHistory": _df_to_rows(t.earnings_history, limit=limit),
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"analysis failed for {sym}: {e}")


@app.get("/ownership/{symbol}")
async def ownership(symbol: str, limit: int = 200):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        return {
            "symbol": sym,
            "majorHolders": _df_to_rows(t.major_holders, limit=limit),
            "institutionalHolders": _df_to_rows(t.institutional_holders, limit=limit),
            "mutualFundHolders": _df_to_rows(t.mutualfund_holders, limit=limit),
            "insiderTransactions": _df_to_rows(t.insider_transactions, limit=limit),
            "insiderRosterHolders": _df_to_rows(t.insider_roster_holders, limit=limit),
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ownership failed for {sym}: {e}")


@app.get("/events/{symbol}")
async def events(symbol: str, limit: int = 500):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        return {
            "symbol": sym,
            "calendar": _sanitize_dict(t.calendar),
            "dividends": _series_to_rows(t.dividends, key="dividend", limit=limit),
            "splits": _series_to_rows(t.splits, key="split", limit=limit),
            "actions": _df_to_rows(t.actions, limit=limit),
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"events failed for {sym}: {e}")


@app.get("/news/{symbol}")
async def news(symbol: str, limit: int = 20):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        items = t.news or []
        out = []
        for item in items[: max(1, min(limit, 100))]:
            out.append(
                {
                    "title": item.get("title"),
                    "publisher": item.get("publisher"),
                    "link": item.get("link") or item.get("canonicalUrl", {}).get("url"),
                    "providerPublishTime": _normalize_value(item.get("providerPublishTime")),
                    "type": item.get("type"),
                    "uuid": item.get("uuid"),
                }
            )
        return {"symbol": sym, "news": out, "source": "yfinance"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"news failed for {sym}: {e}")


@app.get("/options/{symbol}")
async def options(symbol: str, expiration: str | None = None, limit: int = 250):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        expirations = list(t.options or [])
        if not expirations:
            return {"symbol": sym, "expirations": [], "selectedExpiration": None, "calls": [], "puts": []}

        chosen = expiration if expiration in expirations else expirations[0]
        chain = t.option_chain(chosen)
        calls = _df_to_rows(chain.calls, limit=max(1, min(limit, 1000)))
        puts = _df_to_rows(chain.puts, limit=max(1, min(limit, 1000)))
        return {
            "symbol": sym,
            "expirations": expirations,
            "selectedExpiration": chosen,
            "calls": calls,
            "puts": puts,
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"options failed for {sym}: {e}")


@app.get("/macro")
async def macro():
    symbols = {
        "^TNX": "tnx",
        "DX-Y.NYB": "dxy",
        "GC=F": "gold",
        "CL=F": "oil",
        "^VIX": "vix",
    }
    result = {}
    for sym, key in symbols.items():
        try:
            q = await quote(sym)
            result[key] = q
        except Exception:
            result[key] = {"price": 0, "change": 0, "changesPercentage": 0}
    return result
