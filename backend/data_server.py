from __future__ import annotations

import time
import threading
from datetime import datetime, timezone
from typing import Any

import pandas as pd
import yfinance as yf
from cachetools import TTLCache
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="SIGMA yfinance Gateway", version="3.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Cache layers — TTL tuned to data change frequency
# ---------------------------------------------------------------------------
_LOCK = threading.Lock()

_cache_price      = TTLCache(maxsize=500, ttl=30)      # 30s  — price/quote
_cache_history    = TTLCache(maxsize=200, ttl=60)      # 1min — intraday/history
_cache_financials = TTLCache(maxsize=200, ttl=3600)    # 1h   — statements
_cache_analysis   = TTLCache(maxsize=200, ttl=14400)   # 4h   — analyst data
_cache_ownership  = TTLCache(maxsize=200, ttl=14400)   # 4h   — holders
_cache_options    = TTLCache(maxsize=200, ttl=300)     # 5min — options chain
_cache_events     = TTLCache(maxsize=200, ttl=3600)    # 1h   — calendar/divs
_cache_news       = TTLCache(maxsize=200, ttl=300)     # 5min — news

# Stale cache (no TTL) — keeps last known good value across restarts
_stale: dict = {}

_RATE_LIMIT_PHRASES = ("too many requests", "rate limit", "429")


def _is_rate_limit(exc: Exception) -> bool:
    return any(p in str(exc).lower() for p in _RATE_LIMIT_PHRASES)


def _cached(cache: TTLCache, key: str, fn, retries: int = 2, backoff: float = 1.5):
    """Thread-safe cache get-or-set with retry and stale fallback on rate limit."""
    with _LOCK:
        if key in cache:
            return cache[key]
    last_exc = None
    for attempt in range(retries):
        try:
            result = fn()
            with _LOCK:
                cache[key] = result
            _stale[key] = result  # persist last good value
            return result
        except Exception as exc:
            last_exc = exc
            if _is_rate_limit(exc):
                if key in _stale:
                    # Return stale data rather than crashing
                    return {**_stale[key], "_stale": True, "_stale_reason": "rate_limited"}
                if attempt < retries - 1:
                    time.sleep(backoff * (attempt + 1))
            else:
                raise  # non-rate-limit errors bubble up immediately
    raise last_exc


def _safe(val, default=None):
    if val is None:
        return default
    if isinstance(val, float) and pd.isna(val):
        return default
    if isinstance(val, (pd.Timestamp, datetime)):
        return val.isoformat()
    try:
        if pd.isna(val):
            return default
    except Exception:
        pass
    if isinstance(val, (str, bool, int, float)):
        return val
    return str(val)


def _num(val, default=0.0):
    if val is None:
        return default
    try:
        f = float(val)
        return default if pd.isna(f) else f
    except (TypeError, ValueError):
        return default


def _df_to_list(df, limit=200):
    if df is None or not isinstance(df, pd.DataFrame) or df.empty:
        return []
    return [
        {k: _safe(v) for k, v in row.items()}
        for _, row in df.reset_index().head(limit).iterrows()
    ]


def _series_to_list(s, value_key="value", limit=500):
    if s is None or not isinstance(s, pd.Series) or s.empty:
        return []
    return [{"date": _safe(idx), value_key: _safe(val)} for idx, val in s.head(limit).items()]


def _stmt_to_list(df, limit=8):
    if df is None or not isinstance(df, pd.DataFrame) or df.empty:
        return []
    return _df_to_list(df.T, limit=limit)


def _clean(d):
    if isinstance(d, dict):
        return {str(k): _clean(v) for k, v in d.items()}
    if isinstance(d, list):
        return [_clean(v) for v in d]
    if isinstance(d, pd.DataFrame):
        return _df_to_list(d)
    if isinstance(d, pd.Series):
        return _series_to_list(d)
    return _safe(d)


@app.get("/")
async def health():
    return {"status": "ok", "service": "yfinance-gateway", "version": "3.0.0",
            "time": datetime.now(timezone.utc).isoformat()}


@app.get("/search")
async def search_tickers(q: str = Query(..., min_length=1)):
    try:
        results = yf.Search(q).quotes or []
        return [
            {
                "symbol": (i.get("symbol") or "").upper(),
                "name": i.get("shortname") or i.get("longname") or "",
                "exchange": i.get("exchange") or "",
                "exchangeShortName": i.get("exchange") or "",
                "type": i.get("quoteType") or "EQUITY",
            }
            for i in results[:20]
            if i.get("symbol")
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# /quote/{symbol} — lightweight: price + profile + valuation only
# ---------------------------------------------------------------------------
@app.get("/quote/{symbol}")
async def quote(symbol: str):
    """Lightweight quote: price, market data, profile, valuation metrics."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        info = t.info or {}
        fi = t.fast_info

        price = _num(
            info.get("currentPrice")
            or info.get("regularMarketPrice")
            or (fi.get("lastPrice") if fi else None)
        )
        prev = _num(
            info.get("previousClose")
            or info.get("regularMarketPreviousClose")
            or (fi.get("previousClose") if fi else None)
        )
        change = price - prev if prev > 0 else 0
        change_pct = (change / prev * 100) if prev > 0 else 0

        return {
            "symbol": sym,
            "name": info.get("shortName") or info.get("longName") or sym,
            "price": price,
            "previousClose": prev,
            "change": change,
            "changesPercentage": change_pct,
            "changePercent": change_pct,
            "open": _num(info.get("open") or info.get("regularMarketOpen")),
            "dayHigh": _num(info.get("dayHigh") or info.get("regularMarketDayHigh")),
            "dayLow": _num(info.get("dayLow") or info.get("regularMarketDayLow")),
            "volume": _num(info.get("volume") or info.get("regularMarketVolume")),
            "avgVolume": _num(info.get("averageVolume")),
            "marketCap": _num(info.get("marketCap")),
            "fiftyTwoWeekHigh": _num(info.get("fiftyTwoWeekHigh")),
            "fiftyTwoWeekLow": _num(info.get("fiftyTwoWeekLow")),
            "fiftyDayAverage": _num(info.get("fiftyDayAverage")),
            "twoHundredDayAverage": _num(info.get("twoHundredDayAverage")),
            "preMarketPrice": _safe(info.get("preMarketPrice")),
            "postMarketPrice": _safe(info.get("postMarketPrice")),
            "marketState": info.get("marketState") or "UNKNOWN",
            "regularMarketTime": _safe(info.get("regularMarketTime")),
            "currency": info.get("currency") or "USD",
            "exchange": info.get("exchange") or info.get("fullExchangeName") or "",
            "pe": _safe(info.get("trailingPE")),
            "forwardPE": _safe(info.get("forwardPE")),
            "priceToBook": _safe(info.get("priceToBook")),
            "priceToSales": _safe(info.get("priceToSalesTrailing12Months")),
            "eps": _safe(info.get("trailingEps")),
            "forwardEps": _safe(info.get("forwardEps")),
            "dividendYield": _safe(info.get("dividendYield")),
            "dividendRate": _safe(info.get("dividendRate")),
            "exDividendDate": _safe(info.get("exDividendDate")),
            "beta": _safe(info.get("beta")),
            "sharesOutstanding": _safe(info.get("sharesOutstanding")),
            "floatShares": _safe(info.get("floatShares")),
            "sharesShort": _safe(info.get("sharesShort")),
            "shortRatio": _safe(info.get("shortRatio")),
            "shortPercentOfFloat": _safe(info.get("shortPercentOfFloat")),
            "heldPercentInsiders": _safe(info.get("heldPercentInsiders")),
            "heldPercentInstitutions": _safe(info.get("heldPercentInstitutions")),
            "enterpriseValue": _safe(info.get("enterpriseValue")),
            "enterpriseToRevenue": _safe(info.get("enterpriseToRevenue")),
            "enterpriseToEbitda": _safe(info.get("enterpriseToEbitda")),
            "profitMargins": _safe(info.get("profitMargins")),
            "grossMargins": _safe(info.get("grossMargins")),
            "operatingMargins": _safe(info.get("operatingMargins")),
            "returnOnEquity": _safe(info.get("returnOnEquity")),
            "returnOnAssets": _safe(info.get("returnOnAssets")),
            "revenueGrowth": _safe(info.get("revenueGrowth")),
            "earningsGrowth": _safe(info.get("earningsGrowth")),
            "totalRevenue": _safe(info.get("totalRevenue")),
            "ebitda": _safe(info.get("ebitda")),
            "totalDebt": _safe(info.get("totalDebt")),
            "totalCash": _safe(info.get("totalCash")),
            "freeCashflow": _safe(info.get("freeCashflow")),
            "operatingCashflow": _safe(info.get("operatingCashflow")),
            "debtToEquity": _safe(info.get("debtToEquity")),
            "currentRatio": _safe(info.get("currentRatio")),
            "quickRatio": _safe(info.get("quickRatio")),
            "bookValue": _safe(info.get("bookValue")),
            "targetHighPrice": _safe(info.get("targetHighPrice")),
            "targetLowPrice": _safe(info.get("targetLowPrice")),
            "targetMeanPrice": _safe(info.get("targetMeanPrice")),
            "targetMedianPrice": _safe(info.get("targetMedianPrice")),
            "recommendationMean": _safe(info.get("recommendationMean")),
            "recommendationKey": info.get("recommendationKey"),
            "numberOfAnalystOpinions": _safe(info.get("numberOfAnalystOpinions")),
            "sector": info.get("sector"),
            "industry": info.get("industry"),
            "country": info.get("country"),
            "website": info.get("website"),
            "fullTimeEmployees": _safe(info.get("fullTimeEmployees")),
            "description": info.get("longBusinessSummary"),
            "quoteType": info.get("quoteType"),
            "source": "yfinance",
        }

    try:
        return _cached(_cache_price, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"quote failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /financials/{symbol} — income statement, balance sheet, cash flow
# ---------------------------------------------------------------------------
@app.get("/financials/{symbol}")
async def financials(symbol: str):
    """Quarterly & annual financial statements. Cached 1h."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        return {
            "symbol": sym,
            "quarterlyIncomeStatement": _stmt_to_list(t.quarterly_income_stmt),
            "quarterlyBalanceSheet": _stmt_to_list(t.quarterly_balance_sheet),
            "quarterlyCashFlow": _stmt_to_list(t.quarterly_cashflow),
            "annualIncomeStatement": _stmt_to_list(t.income_stmt),
            "annualBalanceSheet": _stmt_to_list(t.balance_sheet),
            "annualCashFlow": _stmt_to_list(t.cashflow),
            "source": "yfinance",
        }

    try:
        return _cached(_cache_financials, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"financials failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /analysis/{symbol} — analyst targets, recommendations, earnings estimates
# ---------------------------------------------------------------------------
@app.get("/analysis/{symbol}")
async def analysis(symbol: str):
    """Analyst price targets, recommendations, earnings/revenue estimates. Cached 4h."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        return {
            "symbol": sym,
            "analystPriceTargets": _clean(t.analyst_price_targets),
            "recommendations": _df_to_list(t.recommendations, limit=20),
            "upgradesDowngrades": _df_to_list(t.upgrades_downgrades, limit=30),
            "earningsHistory": _df_to_list(t.earnings_history, limit=12),
            "earningsEstimate": _df_to_list(t.earnings_estimate),
            "revenueEstimate": _df_to_list(t.revenue_estimate),
            "epsTrend": _df_to_list(t.eps_trend),
            "growthEstimates": _df_to_list(t.growth_estimates),
            "source": "yfinance",
        }

    try:
        return _cached(_cache_analysis, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"analysis failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /ownership/{symbol} — institutional, insider, mutual fund holders
# ---------------------------------------------------------------------------
@app.get("/ownership/{symbol}")
async def ownership(symbol: str):
    """Institutional holders, insider transactions, mutual fund holders. Cached 4h."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        return {
            "symbol": sym,
            "majorHolders": _df_to_list(t.major_holders),
            "institutionalHolders": _df_to_list(t.institutional_holders, limit=25),
            "mutualFundHolders": _df_to_list(t.mutualfund_holders, limit=25),
            "insiderTransactions": _df_to_list(t.insider_transactions, limit=30),
            "insiderRoster": _df_to_list(t.insider_roster_holders, limit=20),
            "source": "yfinance",
        }

    try:
        return _cached(_cache_ownership, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ownership failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /options/{symbol} — options chain for nearest expiration (or specified)
# ---------------------------------------------------------------------------
@app.get("/options/{symbol}")
async def options(symbol: str, expiration: str | None = Query(default=None)):
    """Options chain (calls & puts). Cached 5min. Pass ?expiration=YYYY-MM-DD to select."""
    sym = symbol.upper().strip()
    cache_key = f"{sym}:{expiration or '_default'}"

    def _fetch():
        t = yf.Ticker(sym)
        expirations = list(t.options or [])
        if not expirations:
            return {"symbol": sym, "expirations": [], "calls": [], "puts": [], "source": "yfinance"}

        selected = expiration if expiration in expirations else expirations[0]
        chain = t.option_chain(selected)
        return {
            "symbol": sym,
            "expirations": expirations,
            "selectedExpiration": selected,
            "calls": _df_to_list(chain.calls, limit=100),
            "puts": _df_to_list(chain.puts, limit=100),
            "source": "yfinance",
        }

    try:
        return _cached(_cache_options, cache_key, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"options failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /events/{symbol} — earnings calendar, dividends, splits
# ---------------------------------------------------------------------------
@app.get("/events/{symbol}")
async def events(symbol: str):
    """Earnings calendar, dividend history, stock splits. Cached 1h."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        return {
            "symbol": sym,
            "calendar": _clean(t.calendar),
            "dividends": _series_to_list(t.dividends, value_key="dividend", limit=50),
            "splits": _series_to_list(t.splits, value_key="split", limit=50),
            "source": "yfinance",
        }

    try:
        return _cached(_cache_events, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"events failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /news/{symbol} — latest news articles
# ---------------------------------------------------------------------------
@app.get("/news/{symbol}")
async def news(symbol: str):
    """Latest news articles for a ticker. Cached 5min."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        raw = t.news or []
        items = []
        for item in raw[:20]:
            # yfinance >=0.2.50 wraps articles under item["content"]
            content = item.get("content") or item
            items.append({
                "title": content.get("title"),
                "publisher": (content.get("provider") or {}).get("displayName")
                             or content.get("publisher"),
                "link": (content.get("canonicalUrl") or {}).get("url")
                        or content.get("link"),
                "publishedAt": _safe(
                    content.get("pubDate")
                    or content.get("providerPublishTime")
                ),
                "type": content.get("contentType") or content.get("type"),
            })
        return {"symbol": sym, "articles": items, "source": "yfinance"}

    try:
        return _cached(_cache_news, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"news failed for {sym}: {e}")


@app.get("/multi-quote")
async def multi_quote(symbols: str = Query(..., description="Comma separated symbols")):
    """Lightweight price-only snapshot for a list of tickers. Cached 30s per ticker."""
    sym_list = [s.strip().upper() for s in symbols.split(",") if s.strip()][:50]
    out = []
    for sym in sym_list:
        def _fetch(s=sym):
            t = yf.Ticker(s)
            fi = t.fast_info
            price = _num(fi.get("lastPrice") if fi else 0)
            prev = _num(fi.get("previousClose") if fi else 0)
            change = price - prev if prev > 0 else 0
            change_pct = (change / prev * 100) if prev > 0 else 0
            return {"symbol": s, "price": price, "change": change,
                    "changesPercentage": change_pct, "source": "yfinance"}
        try:
            out.append(_cached(_cache_price, f"fast:{sym}", _fetch))
        except Exception:
            continue
    return out


@app.get("/history/{symbol}")
async def history(symbol: str, range: str = "1mo", interval: str = "1d", prepost: bool = False):
    """OHLCV history. period/interval follow yfinance conventions. Cached 1min."""
    sym = symbol.upper().strip()
    cache_key = f"{sym}:{range}:{interval}:{prepost}"

    def _fetch():
        t = yf.Ticker(sym)
        hist = t.history(period=range, interval=interval, prepost=prepost, auto_adjust=True)
        if hist.empty:
            return []
        rows = []
        for dt, row in hist.iterrows():
            close_val = row.get("Close")
            if close_val is None or pd.isna(close_val):
                continue
            rows.append({
                "date": _safe(dt),
                "open": _safe(row.get("Open")),
                "high": _safe(row.get("High")),
                "low": _safe(row.get("Low")),
                "close": float(close_val),
                "volume": _safe(row.get("Volume")),
            })
        return rows

    try:
        return _cached(_cache_history, cache_key, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"history failed for {sym}: {e}")


@app.get("/intraday/{symbol}")
async def intraday(symbol: str, interval: str = "5m", range: str = "1d", prepost: bool = True):
    """Intraday bars. Delegates to /history with prepost=True."""
    return await history(symbol=symbol, range=range, interval=interval, prepost=prepost)


@app.get("/macro")
async def macro():
    """Global macro snapshot: bonds, DXY, gold, oil, VIX, major indices, BTC. Cached 30s."""
    symbols = {
        "^TNX": "tnx", "DX-Y.NYB": "dxy", "GC=F": "gold", "CL=F": "oil",
        "^VIX": "vix", "^GSPC": "sp500", "^NDX": "nasdaq100",
        "^DJI": "dow", "BTC-USD": "bitcoin",
    }

    def _fetch():
        result = {}
        for sym, key in symbols.items():
            try:
                t = yf.Ticker(sym)
                fi = t.fast_info
                price = _num(fi.get("lastPrice") if fi else 0)
                prev = _num(fi.get("previousClose") if fi else 0)
                change = price - prev if prev > 0 else 0
                change_pct = (change / prev * 100) if prev > 0 else 0
                result[key] = {"symbol": sym, "price": price, "change": change,
                               "changesPercentage": change_pct}
            except Exception:
                result[key] = {"symbol": sym, "price": 0, "change": 0, "changesPercentage": 0}
        return result

    return _cached(_cache_price, "__macro__", _fetch)
