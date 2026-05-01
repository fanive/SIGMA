from __future__ import annotations

import time
import threading
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

import re as _re

import requests as _requests
from bs4 import BeautifulSoup as _BS
import pandas as pd
import yfinance as yf
from cachetools import TTLCache
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="SIGMA yfinance Gateway", version="3.1.0")

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
_cache_insider    = TTLCache(maxsize=200, ttl=14400)   # 4h   — OpenInsider SEC Form 4
_cache_sec        = TTLCache(maxsize=100, ttl=86400)   # 24h  — SEC EDGAR facts

# Stale cache (no TTL) — keeps last known good value across restarts
_stale: dict = {}

_RATE_LIMIT_PHRASES = ("too many requests", "rate limit", "429")


def _is_rate_limit(exc: Exception) -> bool:
    return any(p in str(exc).lower() for p in _RATE_LIMIT_PHRASES)


def _cached(cache: TTLCache, key: str, fn, retries: int = 2, backoff: float = 1.5):
    """Thread-safe cache get-or-set with retry and stale fallback on rate limit."""
    # Namespace stale keys by cache instance to avoid cross-endpoint data collisions.
    stale_key = f"{id(cache)}:{key}"
    with _LOCK:
        if key in cache:
            return cache[key]
    last_exc = None
    for attempt in range(retries):
        try:
            result = fn()
            with _LOCK:
                cache[key] = result
            _stale[stale_key] = result  # persist last good value per endpoint/cache
            return result
        except Exception as exc:
            last_exc = exc
            if _is_rate_limit(exc):
                if stale_key in _stale:
                    # Return stale data rather than crashing
                    return {**_stale[stale_key], "_stale": True, "_stale_reason": "rate_limited"}
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


def _domain_from_website(website: str | None) -> str | None:
    if not website:
        return None
    value = website.strip()
    if not value:
        return None
    parsed = urlparse(value if "://" in value else f"https://{value}")
    host = (parsed.netloc or parsed.path).lower().strip()
    if host.startswith("www."):
        host = host[4:]
    return host or None


def _logo_urls(website: str | None, symbol: str | None = None) -> dict[str, str]:
    """Build a prioritised set of logo URLs for a ticker.

    Priority order (all free, no API key):
      1. Parqet   — ticker-based SVG (best coverage, no key)
      2. FMP      — ticker-based PNG
      3. Clearbit — derived from company website domain
      4. ui-avatars — letter-based placeholder (always works)
    """
    domain = _domain_from_website(website)
    sym = (symbol or "").upper().strip()

    result: dict[str, str] = {}

    # 1. Parqet: works for equities and ETFs, not crypto pairs like BTC-USD
    if sym:
        result["parqet"] = f"https://assets.parqet.com/logos/symbol/{sym}?format=svg"

    # 2. FMP public logo (no key for PNG)
    if sym and "-" not in sym:   # crypto pairs (BTC-USD) not supported
        result["fmp"] = f"https://financialmodelingprep.com/image-stock/{sym}.png"

    # 3. Clearbit via company website domain
    if domain:
        result["clearbit"] = f"https://logo.clearbit.com/{domain}"
        result["favicon"] = f"https://www.google.com/s2/favicons?domain={domain}&sz=128"

    # 4. Universal fallback — always generates a coloured letter logo
    result["placeholder"] = (
        f"https://ui-avatars.com/api/?name={sym or 'X'}"
        f"&size=128&background=0f172a&color=38bdf8&bold=true&format=png"
    )
    result["domain"] = domain or ""

    # Primary = first available in priority order
    result["primary"] = (
        result.get("parqet")
        or result.get("clearbit")
        or result.get("placeholder")
    )
    return result


@app.get("/")
async def health():
    return {"status": "ok", "service": "yfinance-gateway", "version": "3.1.0",
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
                # Search payload does not reliably include website; leave as nullable.
                "logoUrl": None,
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
        website = info.get("website")
        logo = _logo_urls(website, symbol=sym)

        # --- CEO from officers list ---
        officers = info.get("companyOfficers") or []
        ceo = next(
            (o.get("name") for o in officers
             if "ceo" in (o.get("title") or "").lower()
             or "chief executive" in (o.get("title") or "").lower()),
            None,
        )

        # --- 52-week range string (FMP style "low-high") ---
        wk52_low = _num(info.get("fiftyTwoWeekLow"))
        wk52_high = _num(info.get("fiftyTwoWeekHigh"))
        wk52_range = f"{wk52_low}-{wk52_high}" if wk52_low and wk52_high else None

        # --- quoteType-derived booleans ---
        quote_type = info.get("quoteType") or ""
        is_etf = quote_type.upper() == "ETF"
        is_fund = quote_type.upper() in ("MUTUALFUND", "FUND")
        is_adr = bool(info.get("isAdr")) or "adr" in (info.get("longName") or "").lower()

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
            # --- Profile / company identity (FMP-aligned) ---
            "companyName": info.get("shortName") or info.get("longName") or sym,
            "ceo": ceo,
            "phone": info.get("phone"),
            "address": info.get("address1"),
            "city": info.get("city"),
            "state": info.get("state"),
            "zip": info.get("zip"),
            "exchangeFullName": info.get("fullExchangeName") or info.get("exchange") or "",
            "ipoDate": info.get("ipoDate"),
            "range": wk52_range,
            "image": logo.get("primary"),
            "isEtf": is_etf,
            "isFund": is_fund,
            "isAdr": is_adr,
            "isActivelyTrading": info.get("tradeable", True),
            "website": website,
            "logoUrl": logo.get("primary"),
            "logoUrls": logo,
            "fullTimeEmployees": _safe(info.get("fullTimeEmployees")),
            "description": info.get("longBusinessSummary"),
            "quoteType": quote_type,
            "source": "yfinance",
        }

    try:
        return _cached(_cache_price, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"quote failed for {sym}: {e}")


@app.get("/logo/{symbol}")
async def logo(symbol: str):
    """Return logo URLs for a symbol. Ticker-based (Parqet/FMP) + domain fallback."""
    sym = symbol.upper().strip()

    def _fetch():
        # Try to get website from stale quote cache first (avoids a yfinance call)
        website = None
        stale_quote = _stale.get(f"{id(_cache_price)}:{sym}")
        if isinstance(stale_quote, dict):
            website = stale_quote.get("website")
        else:
            try:
                t = yf.Ticker(sym)
                website = (t.info or {}).get("website")
            except Exception:
                pass  # fallback gracefully to ticker-only URLs

        urls = _logo_urls(website, symbol=sym)
        source = "ticker+website" if website else "ticker-only"
        return {
            "symbol": sym,
            "website": website,
            "logoUrl": urls.get("primary"),
            "logoUrls": urls,
            "source": source,
        }

    try:
        return _cached(_cache_price, f"logo:{sym}", _fetch)
    except Exception:
        # Even if everything fails, return ticker-based URLs (always valid)
        urls = _logo_urls(None, symbol=sym)
        return {
            "symbol": sym,
            "website": None,
            "logoUrl": urls.get("primary"),
            "logoUrls": urls,
            "source": "ticker-only",
        }


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
            c = item.get("content") or item
            thumbnail = c.get("thumbnail") or {}
            resolutions = thumbnail.get("resolutions") or []
            thumb_url = thumbnail.get("originalUrl") or (resolutions[0].get("url") if resolutions else None)
            items.append({
                "title": c.get("title"),
                "summary": c.get("summary") or c.get("description"),
                "publisher": (c.get("provider") or {}).get("displayName"),
                "link": (c.get("canonicalUrl") or {}).get("url")
                        or (c.get("clickThroughUrl") or {}).get("url"),
                "publishedAt": c.get("pubDate") or _safe(c.get("providerPublishTime")),
                "type": c.get("contentType") or c.get("type"),
                "thumbnail": thumb_url,
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


# ---------------------------------------------------------------------------
# /insider/{symbol} — SEC Form 4 insider trades via OpenInsider scraper
# ---------------------------------------------------------------------------
_OI_HEADERS = {
    "User-Agent": "SIGMA-App/1.0 contact@sigma.app",
    "Accept-Language": "en-US,en;q=0.9",
}
_OI_COLS = [
    "flag", "filing_date", "trade_date", "ticker", "insider_name",
    "title", "transaction_type", "price", "qty", "owned",
    "delta_own_pct", "value", "perf_1d", "perf_1w", "perf_1m", "perf_6m",
]


def _parse_oi_html(html: str, sym: str) -> list[dict]:
    """Parse the tinytable from OpenInsider HTML into a list of typed trade dicts."""
    soup = _BS(html, "html.parser")
    table = soup.find("table", class_="tinytable")
    if not table:
        return []
    rows = table.find_all("tr")
    result = []
    for row in rows[1:]:  # skip header
        cells = row.find_all(["td", "th"])
        values = [c.get_text(strip=True) for c in cells]
        if len(values) < len(_OI_COLS):
            values += [""] * (len(_OI_COLS) - len(values))
        trade = dict(zip(_OI_COLS, values))

        # Cast numeric fields (strip $, commas, +)
        def _to_num(s: str, as_int: bool = False):
            cleaned = _re.sub(r"[$,+]", "", s).strip()
            if not cleaned or cleaned in ("-", "N/A"):
                return None
            try:
                return int(cleaned) if as_int else float(cleaned)
            except ValueError:
                return None

        trade["price"] = _to_num(trade["price"])
        trade["qty"] = _to_num(trade["qty"], as_int=True)
        trade["owned"] = _to_num(trade["owned"], as_int=True)
        trade["value"] = _to_num(trade["value"])
        # delta_own_pct: strip % → float
        trade["delta_own_pct"] = _to_num(trade.get("delta_own_pct", "").replace("%", ""))
        # is_buy: positive qty or transaction starts with P / A
        tt = trade.get("transaction_type", "")
        trade["is_buy"] = (
            (trade["qty"] is not None and trade["qty"] > 0)
            or tt.startswith(("P -", "A -", "G -", "M -"))
        )
        result.append(trade)
    return result


def _insider_summary(trades: list[dict]) -> dict:
    """Aggregate insider trades into a sentiment summary."""
    buys = [t for t in trades if t.get("is_buy")]
    sells = [t for t in trades if not t.get("is_buy")]

    def _sum_val(lst):
        return round(sum(abs(t["value"]) for t in lst if t.get("value") is not None), 0)

    def _sum_shares(lst):
        return sum(abs(t["qty"]) for t in lst if t.get("qty") is not None)

    # Most active insiders by absolute value traded
    by_insider: dict = {}
    for t in trades:
        name = t.get("insider_name", "Unknown")
        v = abs(t.get("value") or 0)
        if name not in by_insider:
            by_insider[name] = {"insider_name": name, "title": t.get("title", ""), "total_value": 0, "trade_count": 0}
        by_insider[name]["total_value"] += v
        by_insider[name]["trade_count"] += 1

    top_insiders = sorted(by_insider.values(), key=lambda x: x["total_value"], reverse=True)[:5]
    for ins in top_insiders:
        ins["total_value"] = round(ins["total_value"], 0)

    net_val = _sum_val(buys) - _sum_val(sells)
    sentiment = "neutral"
    if net_val > 0:
        sentiment = "bullish"
    elif net_val < 0:
        sentiment = "bearish"

    return {
        "buy_count": len(buys),
        "sell_count": len(sells),
        "buy_value_usd": _sum_val(buys),
        "sell_value_usd": _sum_val(sells),
        "net_value_usd": round(net_val, 0),
        "buy_shares": _sum_shares(buys),
        "sell_shares": _sum_shares(sells),
        "sentiment": sentiment,
        "top_insiders": top_insiders,
    }
@app.get("/insider/{symbol}")
async def insider(symbol: str, days: int = Query(default=365, ge=1, le=1825)):
    """SEC Form 4 insider buys & sells from OpenInsider. Cached 4h.
    `days` controls the lookback window (default 365, max 1825)."""
    sym = symbol.upper().strip()
    cache_key = f"insider:{sym}:{days}"

    def _fetch():
        url = (
            f"http://openinsider.com/screener"
            f"?s={sym}&fd={days}&xp=1&xs=1&cnt=40"
        )
        resp = _requests.get(url, headers=_OI_HEADERS, timeout=15)
        resp.raise_for_status()
        trades = _parse_oi_html(resp.text, sym)
        return {
            "symbol": sym,
            "days": days,
            "count": len(trades),
            "summary": _insider_summary(trades),
            "trades": trades,
            "source": "openinsider.com",
        }

    try:
        return _cached(_cache_insider, cache_key, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"insider fetch failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /sec/{symbol} — SEC EDGAR XBRL company facts (key financial metrics)
# ---------------------------------------------------------------------------
_EDGAR_HEADERS = {"User-Agent": "SIGMA-App/1.0 contact@sigma.app"}
_CIK_MAP: dict = {}  # ticker -> zero-padded CIK string, loaded once
_CIK_MAP_LOCK = threading.Lock()

# Key XBRL facts to extract: (label, taxonomy, concept)
_EDGAR_FACTS = [
    ("revenue", "us-gaap", "RevenueFromContractWithCustomerExcludingAssessedTax"),
    ("revenue", "us-gaap", "Revenues"),
    ("revenue", "us-gaap", "SalesRevenueNet"),
    ("net_income", "us-gaap", "NetIncomeLoss"),
    ("eps_basic", "us-gaap", "EarningsPerShareBasic"),
    ("eps_diluted", "us-gaap", "EarningsPerShareDiluted"),
    ("total_assets", "us-gaap", "Assets"),
    ("total_liabilities", "us-gaap", "Liabilities"),
    ("stockholders_equity", "us-gaap", "StockholdersEquity"),
    ("operating_income", "us-gaap", "OperatingIncomeLoss"),
    ("gross_profit", "us-gaap", "GrossProfit"),
    ("shares_outstanding", "dei", "EntityCommonStockSharesOutstanding"),
]


def _load_cik_map() -> dict:
    global _CIK_MAP
    with _CIK_MAP_LOCK:
        if _CIK_MAP:
            return _CIK_MAP
        resp = _requests.get(
            "https://www.sec.gov/files/company_tickers.json",
            headers=_EDGAR_HEADERS,
            timeout=20,
        )
        resp.raise_for_status()
        raw = resp.json()
        # Format: {"0": {"cik_str": 320193, "ticker": "AAPL", "title": "..."}, ...}
        mapping = {
            v["ticker"].upper(): str(v["cik_str"]).zfill(10)
            for v in raw.values()
        }
        _CIK_MAP = mapping
        return mapping


def _extract_edgar_series(facts_json: dict, taxonomy: str, concept: str, limit: int = 12) -> list[dict]:
    """Pull the most recent entries for a concept, separated by form type."""
    try:
        units = facts_json["facts"][taxonomy][concept]["units"]
    except KeyError:
        return []
    # Prefer USD, fallback to shares or pure numbers
    for unit_key in ("USD", "shares", "pure"):
        entries = units.get(unit_key, [])
        if entries:
            # Keep only 10-K/10-Q filings, sort descending by end date
            filtered = [
                e for e in entries
                if e.get("form") in ("10-K", "10-Q") and e.get("end")
            ]
            filtered.sort(key=lambda e: e["end"], reverse=True)
            # Deduplicate by end date (keep first = most recent filing for that period)
            seen: set = set()
            deduped = []
            for e in filtered:
                key = (e["end"], e.get("form"))
                if key not in seen:
                    seen.add(key)
                    deduped.append({
                        "end": e["end"],
                        "value": e.get("val"),
                        "form": e.get("form"),
                        "filed": e.get("filed"),
                    })
                if len(deduped) >= limit:
                    break
            return deduped
    return []


def _yoy_growth(series: list[dict], form: str = "10-K") -> float | None:
    """Compute YoY growth for the two most recent same-form entries."""
    annual = [e for e in series if e.get("form") == form and e.get("value") is not None]
    if len(annual) < 2:
        return None
    curr, prev = annual[0]["value"], annual[1]["value"]
    if prev == 0:
        return None
    return round((curr - prev) / abs(prev) * 100, 2)


def _compute_sec_derived(extracted: dict[str, list]) -> dict:
    """Compute derived metrics: growth rates, margins, latest snapshot."""
    latest: dict = {}

    # Latest value for each metric (prefer 10-K, fall back to 10-Q)
    for key, series in extracted.items():
        for form in ("10-K", "10-Q"):
            entry = next((e for e in series if e.get("form") == form and e.get("value") is not None), None)
            if entry:
                latest[key] = entry["value"]
                break

    derived: dict = {}

    # YoY growth (annual 10-K)
    for key in ("revenue", "net_income", "gross_profit", "operating_income"):
        if key in extracted:
            g = _yoy_growth(extracted[key], form="10-K")
            if g is not None:
                derived[f"{key}_yoy_growth_pct"] = g

    # Margins (use latest annual values)
    rev = latest.get("revenue")
    if rev and rev != 0:
        if "gross_profit" in latest:
            derived["gross_margin_pct"] = round(latest["gross_profit"] / rev * 100, 2)
        if "operating_income" in latest:
            derived["operating_margin_pct"] = round(latest["operating_income"] / rev * 100, 2)
        if "net_income" in latest:
            derived["net_margin_pct"] = round(latest["net_income"] / rev * 100, 2)

    # Debt-to-equity
    equity = latest.get("stockholders_equity")
    liabilities = latest.get("total_liabilities")
    if equity and equity != 0 and liabilities:
        derived["debt_to_equity"] = round(liabilities / equity, 3)

    derived["latest_values"] = latest
    return derived


@app.get("/sec/{symbol}")
async def sec_facts(symbol: str):
    """Key financial facts from SEC EDGAR XBRL data. Cached 24h.
    Returns revenue, net income, EPS, assets, equity and more."""
    sym = symbol.upper().strip()

    def _fetch():
        cik_map = _load_cik_map()
        cik = cik_map.get(sym)
        if not cik:
            raise HTTPException(status_code=404, detail=f"No SEC CIK found for ticker {sym}")

        url = f"https://data.sec.gov/api/xbrl/companyfacts/CIK{cik}.json"
        resp = _requests.get(url, headers=_EDGAR_HEADERS, timeout=30)
        resp.raise_for_status()
        facts_json = resp.json()

        # Company metadata
        entity_name = facts_json.get("entityName", sym)

        # Extract each metric (revenue may use different concept per company)
        extracted: dict[str, list] = {}
        _revenue_filled = False
        for label, taxonomy, concept in _EDGAR_FACTS:
            if label == "revenue" and _revenue_filled:
                continue  # use first revenue concept that returns data
            series = _extract_edgar_series(facts_json, taxonomy, concept)
            if series:
                extracted[label] = series
                if label == "revenue":
                    _revenue_filled = True

        derived = _compute_sec_derived(extracted)

        # Split each series into annual/quarterly for cleaner client consumption
        facts_split: dict = {}
        for key, series in extracted.items():
            facts_split[key] = {
                "annual": [e for e in series if e.get("form") == "10-K"][:8],
                "quarterly": [e for e in series if e.get("form") == "10-Q"][:12],
            }

        return {
            "symbol": sym,
            "cik": cik,
            "entityName": entity_name,
            "derived": derived,
            "facts": facts_split,
            "source": "sec.gov/edgar",
        }

    try:
        return _cached(_cache_sec, sym, _fetch)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"SEC EDGAR fetch failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /snapshot/{symbol} — combined quote + insider summary + SEC key metrics
# ---------------------------------------------------------------------------
_cache_snapshot = TTLCache(maxsize=200, ttl=60)   # 1min — follows quote TTL


@app.get("/snapshot/{symbol}")
async def snapshot(symbol: str):
    """Single-call snapshot: live quote + insider sentiment + SEC-derived fundamentals.
    Ideal for a stock detail screen. Cached 1min (driven by price TTL)."""
    sym = symbol.upper().strip()

    async def _get_quote():
        try:
            return await quote(sym)
        except Exception:
            return {}

    async def _get_insider_summary():
        try:
            data = await insider(sym, days=365)
            return data.get("summary", {})
        except Exception:
            return {}

    async def _get_sec_derived():
        try:
            data = await sec_facts(sym)
            return data.get("derived", {})
        except Exception:
            return {}

    import asyncio
    quote_data, insider_summary, sec_derived = await asyncio.gather(
        _get_quote(),
        _get_insider_summary(),
        _get_sec_derived(),
    )

    return {
        "symbol": sym,
        "quote": quote_data,
        "insider_sentiment": insider_summary,
        "sec_fundamentals": sec_derived,
        "sources": ["yfinance", "openinsider.com", "sec.gov/edgar"],
    }
