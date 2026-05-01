from __future__ import annotations

from datetime import datetime
from typing import Optional

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


@app.get("/")
async def health():
    return {"status": "ok", "service": "local-yfinance-gateway", "time": datetime.utcnow().isoformat()}


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
            "marketCap": _num(info.get("marketCap")),
            "exchange": info.get("exchange") or info.get("fullExchangeName") or "",
            "currency": info.get("currency") or "USD",
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
async def history(symbol: str, range: str = "1mo", interval: str = "1d"):
    sym = symbol.upper().strip()
    try:
        t = yf.Ticker(sym)
        hist = t.history(period=range, interval=interval)
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
