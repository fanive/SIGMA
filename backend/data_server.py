import os
import time
import threading
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse
import io
import re as _re

import requests as _requests
from bs4 import BeautifulSoup as _BS
import pandas as pd
import yfinance as yf
from cachetools import TTLCache
from fastapi import FastAPI, HTTPException, Query, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="SIGMA yfinance Gateway", version="4.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Routers Definition ---
search_router = APIRouter(prefix="/search", tags=["Search"])
equities_router = APIRouter(prefix="/equities", tags=["Equities"])
market_router = APIRouter(prefix="/market", tags=["Market"])
macro_router = APIRouter(prefix="/macro", tags=["Macro"])

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
_cache_google     = TTLCache(maxsize=200, ttl=300)     # 5min — Google Finance scrape
_cache_coverage   = TTLCache(maxsize=100, ttl=1800)    # 30min — yfinance coverage diagnostics

# Stale cache (no TTL) — keeps last known good value across restarts
_stale: dict = {}

_RATE_LIMIT_PHRASES = ("too many requests", "rate limit", "429")


def _is_rate_limit(exc: Exception) -> bool:
    return any(p in str(exc).lower() for p in _RATE_LIMIT_PHRASES)


class RateLimitError(Exception):
    """Raised by _cached when yfinance rate-limits and no stale data is available."""
    pass


def _cached(cache: TTLCache, key: str, fn, retries: int = 3, backoff: float = 2.5):
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
    # All retries exhausted under rate limit — raise typed error so endpoints can return 429
    raise RateLimitError(str(last_exc))


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


def _yf_get(fn, default=None):
    """Safely read a yfinance property/method that may hit network or be unimplemented."""
    try:
        value = fn()
        return default if value is None else value
    except Exception:
        return default


def _has_payload(value) -> bool:
    if value is None:
        return False
    if isinstance(value, pd.DataFrame):
        return not value.empty
    if isinstance(value, pd.Series):
        return not value.empty
    if isinstance(value, dict):
        return bool(value)
    if isinstance(value, (list, tuple, set)):
        return len(value) > 0
    if isinstance(value, str):
        return bool(value.strip())
    return True


def _yf_count(value) -> int:
    if value is None:
        return 0
    if isinstance(value, pd.DataFrame):
        return len(value.index)
    if isinstance(value, pd.Series):
        return len(value.index)
    if isinstance(value, dict):
        return len(value)
    if isinstance(value, (list, tuple, set)):
        return len(value)
    return 1 if _has_payload(value) else 0


def _yf_probe(label: str, fn, sample_limit: int = 3) -> dict[str, Any]:
    try:
        value = fn()
        sample = _clean(value)
        if isinstance(sample, list):
            sample = sample[:sample_limit]
        elif isinstance(sample, dict):
            sample = dict(list(sample.items())[:sample_limit])
        return {
            "label": label,
            "available": _has_payload(value),
            "count": _yf_count(value),
            "sample": sample,
        }
    except Exception as exc:
        return {
            "label": label,
            "available": False,
            "count": 0,
            "error": str(exc),
        }


def _funds_data_to_dict(funds_data) -> dict[str, Any]:
    if not funds_data:
        return {}
    fields = [
        "description", "fund_overview", "fund_operations", "asset_classes",
        "top_holdings", "equity_holdings", "bond_holdings", "bond_ratings",
        "sector_weightings",
    ]
    out: dict[str, Any] = {}
    for field in fields:
        value = _yf_get(lambda f=field: getattr(funds_data, f), None)
        if _has_payload(value):
            out[field] = _clean(value)
    return out


def _shares_full_to_list(ticker_obj, limit: int = 60) -> list[dict[str, Any]]:
    shares = _yf_get(lambda: ticker_obj.get_shares_full(), None)
    if isinstance(shares, pd.Series):
        return _series_to_list(shares.tail(limit), value_key="shares", limit=limit)
    return []


def _limited_list(value, limit: int = 20) -> list:
    return value[:limit] if isinstance(value, list) else []


def _info_signal_pack(info: dict[str, Any]) -> dict[str, Any]:
    return {
        "currentPrice": _safe(info.get("currentPrice") or info.get("regularMarketPrice")),
        "targetHighPrice": _safe(info.get("targetHighPrice")),
        "targetLowPrice": _safe(info.get("targetLowPrice")),
        "targetMeanPrice": _safe(info.get("targetMeanPrice")),
        "targetMedianPrice": _safe(info.get("targetMedianPrice")),
        "recommendationMean": _safe(info.get("recommendationMean")),
        "recommendationKey": _safe(info.get("recommendationKey")),
        "numberOfAnalystOpinions": _safe(info.get("numberOfAnalystOpinions")),
        "earningsGrowth": _safe(info.get("earningsGrowth")),
        "revenueGrowth": _safe(info.get("revenueGrowth")),
        "pegRatio": _safe(info.get("pegRatio") or info.get("trailingPegRatio")),
        "forwardPE": _safe(info.get("forwardPE")),
        "trailingPE": _safe(info.get("trailingPE")),
        "enterpriseToRevenue": _safe(info.get("enterpriseToRevenue")),
        "enterpriseToEbitda": _safe(info.get("enterpriseToEbitda")),
        "grossMargins": _safe(info.get("grossMargins")),
        "operatingMargins": _safe(info.get("operatingMargins")),
        "profitMargins": _safe(info.get("profitMargins")),
        "returnOnAssets": _safe(info.get("returnOnAssets")),
        "returnOnEquity": _safe(info.get("returnOnEquity")),
        "freeCashflow": _safe(info.get("freeCashflow")),
        "operatingCashflow": _safe(info.get("operatingCashflow")),
        "totalDebt": _safe(info.get("totalDebt")),
        "totalCash": _safe(info.get("totalCash")),
        "shortRatio": _safe(info.get("shortRatio")),
        "shortPercentOfFloat": _safe(info.get("shortPercentOfFloat")),
    }


def _target_fallback_from_info(info: dict[str, Any]) -> dict[str, Any]:
    targets = {
        "current": _safe(info.get("currentPrice") or info.get("regularMarketPrice")),
        "low": _safe(info.get("targetLowPrice")),
        "mean": _safe(info.get("targetMeanPrice")),
        "median": _safe(info.get("targetMedianPrice")),
        "high": _safe(info.get("targetHighPrice")),
        "numberOfAnalysts": _safe(info.get("numberOfAnalystOpinions")),
        "source": "yfinance.info",
    }
    return {k: v for k, v in targets.items() if v is not None}


def _recommendation_fallback_from_info(info: dict[str, Any]) -> list[dict[str, Any]]:
    key = info.get("recommendationKey")
    mean = info.get("recommendationMean")
    count = info.get("numberOfAnalystOpinions")
    if key is None and mean is None and count is None:
        return []
    return [{
        "period": "current",
        "rating": _safe(key),
        "mean": _safe(mean),
        "numberOfAnalystOpinions": _safe(count),
        "source": "yfinance.info",
    }]


def _growth_fallbacks(info: dict[str, Any], sec_derived: dict[str, Any], google_earnings: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for key, label in (
        ("earningsGrowth", "Earnings growth"),
        ("revenueGrowth", "Revenue growth"),
    ):
        value = info.get(key)
        if value is not None:
            rows.append({"metric": label, "value": _safe(value), "source": "yfinance.info"})

    for key, label in (
        ("revenue_yoy_growth_pct", "SEC revenue YoY growth"),
        ("net_income_yoy_growth_pct", "SEC net income YoY growth"),
        ("operating_income_yoy_growth_pct", "SEC operating income YoY growth"),
    ):
        value = sec_derived.get(key)
        if value is not None:
            rows.append({"metric": label, "value": value, "source": "sec.gov/edgar"})

    if google_earnings:
        rows.append({"metric": "Google Finance earnings", "value": google_earnings, "source": "Google Finance"})
    return rows


def _sec_intelligence_fallback(sym: str) -> dict[str, Any]:
    try:
        cik = _load_cik_map().get(sym)
        if not cik:
            return {}
        url = f"https://data.sec.gov/api/xbrl/companyfacts/CIK{cik}.json"
        resp = _requests.get(url, headers=_EDGAR_HEADERS, timeout=20)
        resp.raise_for_status()
        facts_json = resp.json()

        extracted: dict[str, list] = {}
        revenue_filled = False
        for label, taxonomy, concept in _EDGAR_FACTS:
            if label == "revenue" and revenue_filled:
                continue
            series = _extract_edgar_series(facts_json, taxonomy, concept)
            if series:
                extracted[label] = series
                if label == "revenue":
                    revenue_filled = True

        return {
            "cik": cik,
            "entityName": facts_json.get("entityName", sym),
            "derived": _compute_sec_derived(extracted),
            "source": "sec.gov/edgar",
        }
    except Exception as exc:
        return {"error": str(exc), "source": "sec.gov/edgar"}


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
        result["parqet"] = f"https://assets.parqet.com/logos/symbol/{sym}?format=png"

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
    return {"status": "ok", "service": "yfinance-gateway", "version": "4.0.0",
            "time": datetime.now(timezone.utc).isoformat()}


@search_router.get("")
async def search_tickers(q: str = Query(..., min_length=1)):
    try:
        results = yf.Search(q).quotes or []
        out = []
        for i in results[:20]:
            sym = (i.get("symbol") or "").upper()
            if not sym:
                continue
            
            # Fast logo generation without fetching website
            logo_info = _logo_urls(None, symbol=sym)
            
            out.append({
                "symbol": sym,
                "name": i.get("shortname") or i.get("longname") or "",
                "exchange": i.get("exchange") or "",
                "exchangeShortName": i.get("exchange") or "",
                "type": i.get("quoteType") or "EQUITY",
                "logoUrl": logo_info.get("primary"),
                "logoUrls": logo_info,
            })
        return out
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# /quote/{symbol} — lightweight: price + profile + valuation only
# ---------------------------------------------------------------------------
@equities_router.get("/{symbol}/profile")
async def get_equity_profile(symbol: str):
    """Lightweight quote: price, market data, profile, valuation metrics."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        info = t.info or {}
        fi = t.fast_info
        website = info.get("website")
        logo = _logo_urls(website, symbol=sym)

        # --- Enrichment from Google Finance ---
        gf_data = {}
        try:
            gf_data = _scrape_google_finance_safe(sym)
        except:
            pass

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
            "companyName": info.get("shortName") or info.get("longName") or sym,
            "price": price,
            "previousClose": prev,
            "change": change,
            "changePercent": change_pct,
            "open": _num(info.get("open") or info.get("regularMarketOpen")),
            "dayHigh": _num(info.get("dayHigh") or info.get("regularMarketDayHigh")),
            "dayLow": _num(info.get("dayLow") or info.get("regularMarketDayLow")),
            "volume": _num(info.get("volume") or info.get("regularMarketVolume")),
            "marketCap": _num(info.get("marketCap")),
            "fiftyTwoWeekHigh": _num(info.get("fiftyTwoWeekHigh")),
            "fiftyTwoWeekLow": _num(info.get("fiftyTwoWeekLow")),
            "marketState": info.get("marketState") or "UNKNOWN",
            "currency": info.get("currency") or "USD",
            "exchange": info.get("fullExchangeName") or info.get("exchange") or "",
            "pe": _safe(info.get("trailingPE")),
            "eps": _safe(info.get("trailingEps")),
            "beta": _safe(info.get("beta")),
            "dividendYield": _safe(info.get("dividendYield")),
            "sector": info.get("sector"),
            "industry": info.get("industry"),
            "ceo": ceo,
            "website": website,
            "image": logo.get("primary"),
            "description": info.get("longBusinessSummary") or gf_data.get("description"),
            "fullTimeEmployees": _safe(info.get("fullTimeEmployees") or gf_data.get("stats", {}).get("Employees")),
            "source": "yfinance+google",
            # Minimal compatibility aliases for frontend
            "name": info.get("shortName") or info.get("longName") or sym,
            "changesPercentage": change_pct,
            "change_percent": change_pct,
        }

    try:
        return _cached(_cache_price, sym, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"quote failed for {sym}: {e}")


@search_router.get("/logo/{symbol}")
async def logo(symbol: str, json: bool = False):
    """
    Return logo URLs for a symbol. 
    By default redirects to the primary image URL for easy usage in <img> tags.
    Set json=true to get the full JSON metadata.
    """
    sym = symbol.upper().strip()

    def _fetch():
        # Try to get website from stale quote cache first
        website = None
        stale_key = f"{id(_cache_price)}:{sym}"
        stale_quote = _stale.get(stale_key)
        
        if isinstance(stale_quote, dict):
            website = stale_quote.get("website")
        
        if not website:
            try:
                t = yf.Ticker(sym)
                website = (t.info or {}).get("website")
            except Exception:
                pass

        urls = _logo_urls(website, symbol=sym)
        return {
            "symbol": sym,
            "website": website,
            "logoUrl": urls.get("primary"),
            "logoUrls": urls,
        }

    try:
        data = _cached(_cache_price, f"logo:{sym}", _fetch)
        if json:
            return data
        
        logo_url = data.get("logoUrl")
        if logo_url:
            return RedirectResponse(url=logo_url)
        
        # Absolute fallback if no primary URL found
        return RedirectResponse(url=f"https://ui-avatars.com/api/?name={sym}&background=random")
        
    except Exception:
        return RedirectResponse(url=f"https://ui-avatars.com/api/?name={sym}&background=random")


# ---------------------------------------------------------------------------
# /financials/{symbol} — income statement, balance sheet, cash flow
# ---------------------------------------------------------------------------
@equities_router.get("/{symbol}/financials")
async def get_equity_financials(symbol: str):
    """Quarterly & annual financial statements. Cached 1h."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        earnings_dates = _yf_get(lambda: t.get_earnings_dates(limit=16), None)
        shares_full = _shares_full_to_list(t, limit=80)
        return {
            "symbol": sym,
            "quarterlyIncomeStatement": _stmt_to_list(t.quarterly_income_stmt),
            "quarterlyBalanceSheet": _stmt_to_list(t.quarterly_balance_sheet),
            "quarterlyCashFlow": _stmt_to_list(t.quarterly_cashflow),
            "annualIncomeStatement": _stmt_to_list(t.income_stmt),
            "annualBalanceSheet": _stmt_to_list(t.balance_sheet),
            "annualCashFlow": _stmt_to_list(t.cashflow),
            "earningsDates": _df_to_list(earnings_dates, limit=16),
            "sharesOutstandingHistory": shares_full,
            "historyMetadata": _clean(_yf_get(lambda: t.history_metadata, {})),
            "source": "yfinance",
        }

    try:
        return _cached(_cache_financials, sym, _fetch)
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"financials failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /analysis/{symbol} — analyst targets, recommendations, earnings estimates
# ---------------------------------------------------------------------------

def _intelligence_fetch_yf(sym: str) -> dict:
    """Fetch yfinance analyst/earnings data. Called in a thread with timeout."""
    t = yf.Ticker(sym)
    info = _yf_get(lambda: t.info, {}) or {}

    analyst_targets = _clean(_yf_get(lambda: t.analyst_price_targets, {})) or {}
    if not analyst_targets:
        analyst_targets = _target_fallback_from_info(info)

    recommendations = _df_to_list(_yf_get(lambda: t.recommendations, None), limit=10)
    recommendations_summary = _df_to_list(_yf_get(lambda: t.recommendations_summary, None), limit=10)
    if not recommendations_summary:
        recommendations_summary = _recommendation_fallback_from_info(info)

    upgrades_downgrades = _df_to_list(_yf_get(lambda: t.upgrades_downgrades, None), limit=15)
    earnings_history = _df_to_list(_yf_get(lambda: t.earnings_history, None), limit=8)
    earnings_estimate = _df_to_list(_yf_get(lambda: t.earnings_estimate, None))
    revenue_estimate = _df_to_list(_yf_get(lambda: t.revenue_estimate, None))
    eps_trend = _df_to_list(_yf_get(lambda: t.eps_trend, None))
    eps_revisions = _df_to_list(_yf_get(lambda: t.eps_revisions, None))
    growth_estimates = _df_to_list(_yf_get(lambda: t.growth_estimates, None))
    earnings_dates = _df_to_list(_yf_get(lambda: t.get_earnings_dates(limit=16), None), limit=16)

    return {
        "info": info,
        "analyst_targets": analyst_targets,
        "recommendations": recommendations,
        "recommendations_summary": recommendations_summary,
        "upgrades_downgrades": upgrades_downgrades,
        "earnings_history": earnings_history,
        "earnings_estimate": earnings_estimate,
        "revenue_estimate": revenue_estimate,
        "eps_trend": eps_trend,
        "eps_revisions": eps_revisions,
        "growth_estimates": growth_estimates,
        "earnings_dates": earnings_dates,
    }


def _intelligence_fetch_google(sym: str) -> dict:
    """Fetch Google Finance data. Called in a thread with timeout."""
    try:
        return _scrape_google_finance_safe(sym) or {}
    except Exception:
        return {}


def _intelligence_fetch_sec(sym: str) -> dict:
    """Fetch SEC derived data. Called in a thread with timeout."""
    return _sec_intelligence_fallback(sym)


@equities_router.get("/{symbol}/intelligence")
async def get_equity_intelligence(symbol: str):
    """Analyst intelligence with parallel fallback from profile, SEC, and Google Finance. Cached 4h."""
    sym = symbol.upper().strip()

    def _fetch():
        import concurrent.futures

        # Run the three slow sources in parallel with per-source timeouts.
        # yfinance is the primary; Google + SEC are enrichment only.
        # Individual timeouts ensure a single slow source cannot kill the worker.
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            fut_yf = pool.submit(_intelligence_fetch_yf, sym)
            fut_gf = pool.submit(_intelligence_fetch_google, sym)
            fut_sec = pool.submit(_intelligence_fetch_sec, sym)

            try:
                yf_data = fut_yf.result(timeout=25)
            except Exception:
                yf_data = {}

            try:
                google = fut_gf.result(timeout=10)
            except Exception:
                google = {}

            try:
                sec = fut_sec.result(timeout=12)
            except Exception:
                sec = {}

        info = yf_data.get("info", {})
        sec_derived = sec.get("derived", {}) if isinstance(sec, dict) else {}
        google_earnings = google.get("earnings", {}) if isinstance(google, dict) else {}

        analyst_targets = yf_data.get("analyst_targets", {})
        recommendations = yf_data.get("recommendations", [])
        recommendations_summary = yf_data.get("recommendations_summary", [])
        growth_estimates = yf_data.get("growth_estimates", [])
        if not growth_estimates:
            growth_estimates = _growth_fallbacks(info, sec_derived, google_earnings)

        return {
            "symbol": sym,
            "analystPriceTargets": analyst_targets,
            "recommendations": recommendations,
            "recommendationsSummary": recommendations_summary,
            "upgradesDowngrades": yf_data.get("upgrades_downgrades", []),
            "earningsHistory": yf_data.get("earnings_history", []),
            "earningsEstimate": yf_data.get("earnings_estimate", []),
            "revenueEstimate": yf_data.get("revenue_estimate", []),
            "epsTrend": yf_data.get("eps_trend", []),
            "epsRevisions": yf_data.get("eps_revisions", []),
            "growthEstimates": growth_estimates,
            "earningsDates": yf_data.get("earnings_dates", []),
            "profileSignals": _info_signal_pack(info),
            "fallbackSignals": {
                "target": _target_fallback_from_info(info),
                "recommendation": _recommendation_fallback_from_info(info),
                "growth": _growth_fallbacks(info, sec_derived, google_earnings),
            },
            "secDerived": sec_derived,
            "googleFinance": {
                "name": google.get("name") if isinstance(google, dict) else None,
                "priceValue": google.get("priceValue") if isinstance(google, dict) else None,
                "stats": google.get("stats", {}) if isinstance(google, dict) else {},
                "normalizedStats": google.get("normalizedStats", {}) if isinstance(google, dict) else {},
                "earnings": google_earnings,
                "financials": {
                    "rows": _limited_list((google.get("financials") or {}).get("rows"), 24)
                    if isinstance(google, dict) and isinstance(google.get("financials"), dict)
                    else [],
                },
                "peers": _limited_list(google.get("peers"), 12) if isinstance(google, dict) else [],
                "news": _limited_list(google.get("news"), 8) if isinstance(google, dict) else [],
                "source": "Google Finance",
            },
            "dataSources": {
                "yfinanceAnalystTargets": bool(analyst_targets),
                "yfinanceRecommendations": bool(recommendations or recommendations_summary),
                "yfinanceEarningsEstimates": bool(yf_data.get("earnings_estimate")),
                "profileInfoFallback": bool(info),
                "googleFinanceFallback": bool(google and not google.get("error")),
                "secFallback": bool(sec_derived),
            },
            "source": "yfinance+profile+google-finance+sec",
        }

    try:
        return _cached(_cache_analysis, sym, _fetch)
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"analysis failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /ownership/{symbol} — institutional, insider, mutual fund holders
# ---------------------------------------------------------------------------
@equities_router.get("/{symbol}/ownership")
async def get_equity_ownership(symbol: str):
    """Institutional holders, insider transactions, mutual fund holders. Cached 4h."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        funds_data = _funds_data_to_dict(_yf_get(lambda: t.funds_data, None))
        # Pruned: only ownership-specific data
        return {
            "symbol": sym,
            "majorHolders": _df_to_list(_yf_get(lambda: t.major_holders, None), limit=20),
            "institutionalHolders": _df_to_list(t.institutional_holders, limit=20),
            "mutualFundHolders": _df_to_list(t.mutualfund_holders, limit=20),
            "insiderTransactions": _df_to_list(t.insider_transactions, limit=25),
            "insiderPurchases": _df_to_list(_yf_get(lambda: t.insider_purchases, None), limit=25),
            "sustainability": _df_to_list(_yf_get(lambda: t.sustainability, None), limit=40),
            "sharesOutstandingHistory": _shares_full_to_list(t, limit=80),
            "isin": _yf_get(lambda: t.get_isin(), None),
            "fundsData": funds_data,
            "source": "yfinance",
        }

    try:
        return _cached(_cache_ownership, sym, _fetch)
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ownership failed for {sym}: {e}")


@equities_router.get("/{symbol}/yfinance-coverage")
async def get_equity_yfinance_coverage(symbol: str):
    """Live yfinance coverage report showing which data families are available for a ticker."""
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        probes = [
            _yf_probe("info", lambda: t.info),
            _yf_probe("fast_info", lambda: dict(t.fast_info or {})),
            _yf_probe("history_1mo_1d", lambda: t.history(period="1mo", interval="1d")),
            _yf_probe("income_stmt", lambda: t.income_stmt),
            _yf_probe("quarterly_income_stmt", lambda: t.quarterly_income_stmt),
            _yf_probe("balance_sheet", lambda: t.balance_sheet),
            _yf_probe("quarterly_balance_sheet", lambda: t.quarterly_balance_sheet),
            _yf_probe("cashflow", lambda: t.cashflow),
            _yf_probe("quarterly_cashflow", lambda: t.quarterly_cashflow),
            _yf_probe("analyst_price_targets", lambda: t.analyst_price_targets),
            _yf_probe("recommendations", lambda: t.recommendations),
            _yf_probe("recommendations_summary", lambda: t.recommendations_summary),
            _yf_probe("upgrades_downgrades", lambda: t.upgrades_downgrades),
            _yf_probe("earnings_history", lambda: t.earnings_history),
            _yf_probe("earnings_estimate", lambda: t.earnings_estimate),
            _yf_probe("revenue_estimate", lambda: t.revenue_estimate),
            _yf_probe("eps_trend", lambda: t.eps_trend),
            _yf_probe("eps_revisions", lambda: t.eps_revisions),
            _yf_probe("growth_estimates", lambda: t.growth_estimates),
            _yf_probe("earnings_dates", lambda: t.get_earnings_dates(limit=16)),
            _yf_probe("calendar", lambda: t.calendar),
            _yf_probe("dividends", lambda: t.dividends),
            _yf_probe("splits", lambda: t.splits),
            _yf_probe("options_expirations", lambda: list(t.options or [])),
            _yf_probe("news", lambda: t.news),
            _yf_probe("major_holders", lambda: t.major_holders),
            _yf_probe("institutional_holders", lambda: t.institutional_holders),
            _yf_probe("mutualfund_holders", lambda: t.mutualfund_holders),
            _yf_probe("insider_transactions", lambda: t.insider_transactions),
            _yf_probe("insider_purchases", lambda: t.insider_purchases),
            _yf_probe("sustainability", lambda: t.sustainability),
            _yf_probe("shares_full", lambda: t.get_shares_full()),
            _yf_probe("isin", lambda: t.get_isin()),
            _yf_probe("funds_data", lambda: _funds_data_to_dict(t.funds_data)),
            _yf_probe("history_metadata", lambda: t.history_metadata),
        ]
        available = [p["label"] for p in probes if p.get("available")]
        missing = [p["label"] for p in probes if not p.get("available")]
        return {
            "symbol": sym,
            "availableCount": len(available),
            "totalChecked": len(probes),
            "coverageRatio": round(len(available) / len(probes), 3) if probes else 0,
            "available": available,
            "missing": missing,
            "probes": probes,
            "recommendations": [
                "Use /ownership for majorHolders, sustainability, insiderPurchases, sharesOutstandingHistory, and fundsData.",
                "Use /intelligence for epsTrend, epsRevisions, growthEstimates, and earningsDates.",
                "Use /financials for statements plus earningsDates, sharesOutstandingHistory, and historyMetadata.",
            ],
            "source": "yfinance",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    try:
        return _cached(_cache_coverage, sym, _fetch)
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"yfinance coverage failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /options/{symbol} — options chain for nearest expiration (or specified)
# ---------------------------------------------------------------------------
@equities_router.get("/{symbol}/options")
async def get_equity_options(symbol: str, expiration: str | None = Query(default=None)):
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
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"options failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /events/{symbol} — earnings calendar, dividends, splits
# ---------------------------------------------------------------------------
@equities_router.get("/{symbol}/events")
async def get_equity_events(symbol: str):
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
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"events failed for {sym}: {e}")


# ---------------------------------------------------------------------------
# /news/{symbol} — latest news articles
# ---------------------------------------------------------------------------
@equities_router.get("/{symbol}/news")
async def get_equity_news(symbol: str):
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
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"news failed for {sym}: {e}")


@market_router.get("/quotes")
async def multi_quote(symbols: str = Query(..., description="Comma separated symbols")):
    """Fast, lightweight price-only snapshot for watchlists. No logos or enrichment."""
    sym_list = [s.strip().upper() for s in symbols.split(",") if s.strip()][:50]
    out = []

    for s in sym_list:
        def _fetch_fast(sym=s):
            t = yf.Ticker(sym)
            fi = t.fast_info
            info = t.info or {}
            price = _num(fi.get("lastPrice") or info.get("regularMarketPrice"))
            prev = _num(fi.get("previousClose") or info.get("regularMarketPreviousClose"))
            change = price - prev if prev > 0 else 0
            change_pct = (change / prev * 100) if prev > 0 else 0
            return {
                "symbol": sym,
                "companyName": info.get("shortName") or info.get("longName") or sym,
                "price": price,
                "changePercent": change_pct,
                "marketCap": _num(fi.get("marketCap")),
            }

        try:
            # Cache key prefixed with 'fast:' to avoid collision with heavy profile data
            q = _cached(_cache_price, f"fast:{s}", _fetch_fast)
            out.append(q)
        except Exception:
            continue
    return out


@equities_router.get("/{symbol}/history")
async def get_equity_history(symbol: str, range: str = "1mo", interval: str = "1d", prepost: bool = False):
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
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"history failed for {sym}: {e}")


@equities_router.get("/{symbol}/intraday")
async def get_equity_intraday(symbol: str, interval: str = "5m", range: str = "1d", prepost: bool = True):
    """Intraday bars. Delegates to /history with prepost=True."""
    return await history(symbol=symbol, range=range, interval=interval, prepost=prepost)


@market_router.get("/indices")
async def get_market_indices():
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


def _scrape_movers(mover_type: str):
    """Scrapes Yahoo Finance for top gainers/losers/most-active."""
    # Maps internal type to Yahoo URL segment
    url = f"https://finance.yahoo.com/markets/stocks/{mover_type}/"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    try:
        resp = _requests.get(url, headers=headers, timeout=10)
        if resp.status_code != 200:
            return []
        soup = _BS(resp.text, "html.parser")
        # In the new layout, movers are in a table with class 'markets-table' or similar
        table = soup.find("table")
        if not table:
            return []
        
        rows = table.find_all("tr")[1:] # skip header
        out = []
        for r in rows:
            cols = r.find_all("td")
            if len(cols) < 5: continue
            
            # The structure of the table
            symbol = cols[0].text.strip()
            name = cols[1].text.strip()
            price = _num(cols[2].text.strip().replace(",", ""))
            # Change and Change % are often in cols 3 and 4
            change = _num(cols[3].text.strip().replace(",", "").replace("+", ""))
            change_pct = _num(cols[4].text.strip().replace("%", "").replace(",", "").replace("+", ""))
            
            out.append({
                "symbol": symbol,
                "name": name,
                "price": price,
                "change": change,
                "changesPercentage": change_pct
            })
        return out[:25]
    except Exception as e:
        print(f"Scrape {mover_type} failed: {e}")
        return []


@market_router.get("/gainers")
async def get_gainers():
    """Real-time US top gainers. Scraped from Yahoo Finance. Cached 5m."""
    return _cached(_cache_price, "movers:gainers", lambda: _scrape_movers("gainers"))


@market_router.get("/losers")
async def get_losers():
    """Real-time US top losers. Scraped from Yahoo Finance. Cached 5m."""
    return _cached(_cache_price, "movers:losers", lambda: _scrape_movers("losers"))


@market_router.get("/most-active")
async def get_most_active():
    """Real-time US most active stocks. Scraped from Yahoo Finance. Cached 5m."""
    return _cached(_cache_price, "movers:active", lambda: _scrape_movers("most-active"))


@market_router.get("/news")
async def get_market_news(limit: int = 30):
    """Real-time market news from multiple sources. Cached 5m."""
    def _fetch():
        articles = []
        # Source 1: yfinance news for SPY (general market)
        try:
            t = yf.Ticker("SPY")
            for n in (t.news or [])[:15]:
                articles.append({
                    "title": n.get("title", ""),
                    "source": n.get("publisher", "Yahoo Finance"),
                    "url": n.get("link", ""),
                    "publishedAt": n.get("providerPublishTime", ""),
                    "summary": n.get("title", ""),
                    "ticker": "SPY",
                })
        except Exception as e:
            print(f"SPY news fetch failed: {e}")
        
        # Source 2: yfinance news for QQQ (tech)
        try:
            t2 = yf.Ticker("QQQ")
            for n in (t2.news or [])[:10]:
                title = n.get("title", "")
                if not any(a["title"] == title for a in articles):
                    articles.append({
                        "title": title,
                        "source": n.get("publisher", "Yahoo Finance"),
                        "url": n.get("link", ""),
                        "publishedAt": n.get("providerPublishTime", ""),
                        "summary": title,
                        "ticker": "QQQ",
                    })
        except Exception as e:
            print(f"QQQ news fetch failed: {e}")
        
        # Source 3: yfinance news for DIA (blue chips)
        try:
            t3 = yf.Ticker("DIA")
            for n in (t3.news or [])[:8]:
                title = n.get("title", "")
                if not any(a["title"] == title for a in articles):
                    articles.append({
                        "title": title,
                        "source": n.get("publisher", "Yahoo Finance"),
                        "url": n.get("link", ""),
                        "publishedAt": n.get("providerPublishTime", ""),
                        "summary": title,
                        "ticker": "DIA",
                    })
        except Exception as e:
            print(f"DIA news fetch failed: {e}")

        return articles[:limit]

    return _cached(_cache_price, f"market_news:{limit}", _fetch)


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
@equities_router.get("/{symbol}/insider")
async def get_equity_insider(symbol: str, days: int = Query(default=365, ge=1, le=1825)):
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
    except RateLimitError as e:
        raise HTTPException(status_code=429, detail={"error": "rate_limited", "symbol": sym, "message": str(e), "retryAfter": 60})
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


@equities_router.get("/{symbol}/sec")
async def get_equity_sec_facts(symbol: str):
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


@equities_router.get("/{symbol}/snapshot")
async def get_equity_snapshot(symbol: str):
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
# ---------------------------------------------------------------------------
# /stooq/{symbol} — International historical data via Stooq CSV
# ---------------------------------------------------------------------------
_cache_stooq = TTLCache(maxsize=100, ttl=3600)  # 1h

@equities_router.get("/{symbol}/stooq")
async def get_equity_stooq_history(symbol: str, range: str = "1mo"):
    """
    International historical data from Stooq (CSV).
    Supported suffixes: .US, .JP, .UK, .PL, .DE, .HK, etc.
    Example: AAPL.US, 6758.JP (Sony), BMW.DE
    """
    sym = symbol.upper().strip()
    cache_key = f"{sym}:{range}"

    def _fetch():
        # Stooq range mapping (approximate)
        # s=d (daily), f=sd2ohlcv (format)
        url = f"https://stooq.com/q/d/l/?s={sym}&f=sd2ohlcv&h&e=csv"
        resp = _requests.get(url, timeout=15)
        resp.raise_for_status()
        
        if "Exceeded the daily hits limit" in resp.text:
            raise Exception("Stooq rate limit exceeded")
            
        df = pd.read_csv(io.StringIO(resp.text))
        if df.empty:
            return []
            
        # Clean column names (sometimes they have spaces or weird casing)
        df.columns = [c.lower() for c in df.columns]
        
        # Sort by date
        if 'date' in df.columns:
            df['date'] = pd.to_datetime(df['date'])
            df = df.sort_values('date', ascending=True)
            
        # Filter by range (very basic implementation)
        if range == "1mo":
            df = df.tail(30)
        elif range == "1y":
            df = df.tail(252)
            
        return _df_to_list(df)

    try:
        return _cached(_cache_stooq, cache_key, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stooq fetch failed for {sym}: {e}")

# ---------------------------------------------------------------------------
# /fred/{series_id} — Federal Reserve Economic Data (FRED)
# ---------------------------------------------------------------------------
_cache_fred = TTLCache(maxsize=100, ttl=86400)  # 24h

@macro_router.get("/fred/{series_id}")
async def get_macro_fred_series(series_id: str):
    """
    Economic indicators from FRED. Requires FRED_API_KEY in .env.
    Common series: UNRATE (Unemployment), GDP, CPIAUCSL (CPI), FEDFUNDS.
    """
    sid = series_id.upper().strip()
    api_key = os.getenv("FRED_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="FRED_API_KEY not configured in .env")

    def _fetch():
        url = "https://api.stlouisfed.org/fred/series/observations"
        params = {
            "series_id": sid,
            "api_key": api_key,
            "file_type": "json",
            "sort_order": "desc",
            "limit": 100
        }
        resp = _requests.get(url, params=params, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        
        obs = data.get("observations", [])
        return [
            {
                "date": o.get("date"),
                "value": _num(o.get("value"), default=None)
            }
            for o in obs
        ]

    try:
        return _cached(_cache_fred, sid, _fetch)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"FRED fetch failed for {sid}: {e}")

# ---------------------------------------------------------------------------
# Google Finance Scraper
# ---------------------------------------------------------------------------

@equities_router.get("/{ticker}/google-finance")
def get_equity_google_finance_info(ticker: str):
    """
    Scrapes Google Finance for quote metadata, about text, key stats, related news,
    and peer cards. This endpoint is an enrichment source; yfinance/SEC remain the
    canonical structured-data sources.
    """
    return _cached(_cache_google, f"gf:{ticker.upper().strip()}", lambda: _scrape_google_finance_safe(ticker, raise_on_error=True))


_GF_EXCHANGES = [
    "NASDAQ", "NYSE", "NYSEARCA", "NYSEAMERICAN", "OTCMKTS", "BATS", "AMEX",
    "TSE", "TSX", "LON", "ETR", "FRA", "EPA", "BIT", "SWX", "AMS", "STO",
    "CPH", "HEL", "HKG", "TYO", "NSE", "BOM", "ASX",
]


def _gf_clean_text(value: str | None) -> str:
    return _re.sub(r"\s+", " ", value or "").strip()


def _gf_number(value: str | None):
    text = _gf_clean_text(value)
    if not text or text in {"-", "N/A"}:
        return None

    multiplier = 1.0
    upper = text.upper()
    if upper.endswith("T"):
        multiplier = 1e12
    elif upper.endswith("B"):
        multiplier = 1e9
    elif upper.endswith("M"):
        multiplier = 1e6
    elif upper.endswith("K"):
        multiplier = 1e3

    cleaned = _re.sub(r"[^0-9.\-]", "", text)
    if not cleaned or cleaned in {"-", "."}:
        return None
    try:
        return float(cleaned) * multiplier
    except ValueError:
        return None


def _gf_abs_url(href: str | None) -> str:
    if not href:
        return ""
    href = href.strip()
    if href.startswith("http"):
        return href
    if href.startswith("/"):
        return f"https://www.google.com{href}"
    return href


def _gf_first_text(soup, selectors: list[str]) -> str:
    for selector in selectors:
        el = soup.select_one(selector)
        text = _gf_clean_text(el.get_text(" ") if el else "")
        if text:
            return text
    return ""


def _gf_candidate_quotes(ticker: str) -> list[tuple[str, str | None, str]]:
    raw = ticker.upper().strip()
    if not raw:
        return []

    candidates: list[tuple[str, str | None, str]] = []
    seen: set[str] = set()

    def add(symbol: str, exchange: str | None):
        symbol = symbol.strip().upper()
        if not symbol:
            return
        quote = f"{symbol}:{exchange}" if exchange else symbol
        if quote in seen:
            return
        seen.add(quote)
        candidates.append((symbol, exchange, quote))

    if ":" in raw:
        symbol, exchange = raw.split(":", 1)
        add(symbol, exchange)
    else:
        variants = [raw]
        if "-" in raw:
            variants.append(raw.replace("-", "."))
        if "." in raw:
            variants.append(raw.replace(".", "-"))
        for symbol in dict.fromkeys(variants):
            for exchange in _GF_EXCHANGES:
                add(symbol, exchange)
            add(symbol, None)
    return candidates


def _gf_extract_stats(soup) -> dict[str, str]:
    stats: dict[str, str] = {}

    # Current desktop layout usually exposes paired label/value nodes.
    labels = soup.select("div.SwQK7, div.mfs7Fc, div.gyFHrc .mfs7Fc")
    values = soup.select("div.dO6ijd, div.P6K39c, div.gyFHrc .P6K39c")
    for label, value in zip(labels, values):
        key = _gf_clean_text(label.get_text(" "))
        val = _gf_clean_text(value.get_text(" "))
        if key and val and key not in stats:
            stats[key] = val

    # Fallback: each stat card contains both label and value.
    for card in soup.select("div.gyFHrc"):
        key = _gf_first_text(card, ["div.mfs7Fc", "div.SwQK7"])
        val = _gf_first_text(card, ["div.P6K39c", "div.dO6ijd"])
        if key and val and key not in stats:
            stats[key] = val

    return stats


def _gf_normalize_stats(stats: dict[str, str]) -> dict[str, Any]:
    aliases = {
        "Previous close": "previousClose",
        "Day range": "dayRange",
        "Year range": "yearRange",
        "Market cap": "marketCap",
        "Avg Volume": "averageVolume",
        "P/E ratio": "peRatio",
        "Dividend yield": "dividendYield",
        "Primary exchange": "primaryExchange",
        "CEO": "ceo",
        "Founded": "founded",
        "Employees": "employees",
        "Headquarters": "headquarters",
    }
    out: dict[str, Any] = {}
    for label, raw in stats.items():
        key = aliases.get(label)
        if not key:
            key = _re.sub(r"[^a-zA-Z0-9]+", "_", label).strip("_")
            key = key[:1].lower() + key[1:]
        out[key] = {
            "raw": raw,
            "value": _gf_number(raw),
        }
    return out


def _gf_extract_news(soup) -> list[dict[str, str]]:
    news = []
    seen = set()
    for anchor in soup.select('a[href*="/articles/"], a[href*="news.google.com"], a[href^="./articles/"]'):
        title = _gf_clean_text(anchor.get_text(" "))
        href = _gf_abs_url(anchor.get("href"))
        if len(title) < 12 or not href:
            continue
        key = (title.lower(), href)
        if key in seen:
            continue
        seen.add(key)
        parent = anchor.find_parent(["div", "article"])
        parent_text = _gf_clean_text(parent.get_text(" ") if parent else "")
        source = ""
        published = ""
        if parent_text and parent_text != title:
            parts = [p.strip() for p in _re.split(r"\s{2,}| · | - ", parent_text) if p.strip()]
            for part in parts:
                if part != title and len(part) <= 40 and not source:
                    source = part
                if _re.search(r"\b(min|hour|day|week|month|ago|yesterday|today)\b", part, _re.I):
                    published = part
        news.append({"title": title, "source": source, "url": href, "published": published})
        if len(news) >= 8:
            break
    return news


def _gf_extract_peers(soup, ticker: str) -> list[dict[str, str]]:
    peers = []
    seen = {ticker.upper()}
    for anchor in soup.select('a[href*="/finance/quote/"]'):
        href = anchor.get("href") or ""
        match = _re.search(r"/finance/quote/([^?/#]+)", href)
        if not match:
            continue
        quote = match.group(1).upper()
        symbol = quote.split(":", 1)[0]
        if symbol in seen:
            continue
        seen.add(symbol)
        label = _gf_clean_text(anchor.get_text(" "))
        peers.append({
            "symbol": symbol,
            "quote": quote,
            "exchange": quote.split(":", 1)[1] if ":" in quote else "",
            "label": label,
            "url": _gf_abs_url(href),
        })
        if len(peers) >= 12:
            break
    return peers


def _gf_unique_cells(cells: list[str]) -> list[str]:
    out: list[str] = []
    for cell in cells:
        clean = _gf_clean_text(cell)
        if not clean:
            continue
        if out and out[-1] == clean:
            continue
        out.append(clean)
    return out


def _gf_extract_html_tables(soup) -> list[dict[str, Any]]:
    tables: list[dict[str, Any]] = []
    for table_index, table in enumerate(soup.find_all("table")):
        headers = [
            _gf_clean_text(cell.get_text(" "))
            for cell in table.find_all(["th"])
            if _gf_clean_text(cell.get_text(" "))
        ]
        rows: list[dict[str, Any]] = []
        for tr in table.find_all("tr"):
            cells = _gf_unique_cells([
                cell.get_text(" ") for cell in tr.find_all(["th", "td"])
            ])
            if len(cells) < 2:
                continue
            rows.append({
                "label": cells[0],
                "values": cells[1:],
                "numericValues": [_gf_number(v) for v in cells[1:]],
                "raw": cells,
            })
        if rows:
            tables.append({"index": table_index, "headers": headers, "rows": rows})
    return tables


def _gf_extract_div_financial_rows(soup) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[tuple[str, tuple[str, ...]]] = set()
    selectors = [
        '[role="row"]',
        "div.roXhBd",
        "div.yNnsfe",
        "div.J9Jhg",
        "div.P6K39c",
    ]

    for selector in selectors:
        for node in soup.select(selector):
            children = node.find_all(["div", "span"], recursive=False)
            cells = _gf_unique_cells([
                child.get_text(" ") for child in children
            ])
            if len(cells) < 2:
                nested = node.find_all(["div", "span"])
                cells = _gf_unique_cells([
                    child.get_text(" ") for child in nested
                    if not child.find(["div", "span"])
                ])
            if len(cells) < 2 or len(cells[0]) > 80:
                continue
            key = (cells[0].lower(), tuple(cells[1:]))
            if key in seen:
                continue
            seen.add(key)
            rows.append({
                "label": cells[0],
                "values": cells[1:8],
                "numericValues": [_gf_number(v) for v in cells[1:8]],
                "raw": cells[:9],
            })
    return rows


def _gf_statement_kind(label: str) -> str:
    lower = label.lower()
    income_tokens = [
        "revenue", "sales", "gross profit", "operating income", "net income",
        "ebit", "ebitda", "earnings", "eps", "diluted", "basic",
        "cost of revenue", "income before tax", "tax provision",
    ]
    balance_tokens = [
        "assets", "liabilities", "equity", "debt", "cash and short",
        "inventory", "receivables", "payables", "book value", "retained",
        "working capital", "total cash", "shareholders",
    ]
    cash_tokens = [
        "cash flow", "free cash", "operating cash", "capital expenditure",
        "capex", "financing", "investing", "depreciation", "amortization",
        "dividend paid", "stock based compensation", "repurchase",
    ]
    if any(token in lower for token in cash_tokens):
        return "cashFlow"
    if any(token in lower for token in balance_tokens):
        return "balanceSheet"
    if any(token in lower for token in income_tokens):
        return "incomeStatement"
    return "other"


def _gf_extract_periods(rows: list[dict[str, Any]]) -> list[str]:
    for row in rows[:8]:
        raw = row.get("raw") or []
        label = str(row.get("label") or "").lower()
        values = [str(v) for v in row.get("values") or []]
        if label in {"", "period", "year", "quarter"} or "period" in label:
            periods = [v for v in values if _re.search(r"\b(20\d{2}|19\d{2}|q[1-4]|ttm|fy)\b", v, _re.I)]
            if periods:
                return periods
        raw_periods = [v for v in raw if _re.search(r"\b(20\d{2}|19\d{2}|q[1-4]|ttm|fy)\b", str(v), _re.I)]
        if len(raw_periods) >= 2:
            return raw_periods[1:]
    return []


def _gf_rows_by_statement(rows: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped = {
        "incomeStatement": [],
        "balanceSheet": [],
        "cashFlow": [],
        "other": [],
    }
    for row in rows:
        kind = _gf_statement_kind(row.get("label", ""))
        grouped[kind].append(row)
    return grouped


def _gf_extract_earnings(financial_rows: list[dict[str, Any]], stats: dict[str, str]) -> dict[str, Any]:
    def rows_containing(*tokens: str) -> list[dict[str, Any]]:
        lowered = [t.lower() for t in tokens]
        return [
            row for row in financial_rows
            if any(token in str(row.get("label", "")).lower() for token in lowered)
        ]

    eps_rows = rows_containing("eps", "earnings per share", "diluted")
    net_income_rows = rows_containing("net income", "net earnings")
    revenue_rows = rows_containing("revenue", "sales")
    operating_income_rows = rows_containing("operating income", "ebit")

    return {
        "epsRows": eps_rows[:6],
        "netIncomeRows": net_income_rows[:6],
        "revenueRows": revenue_rows[:6],
        "operatingIncomeRows": operating_income_rows[:6],
        "ttmPe": stats.get("P/E ratio"),
        "dividendYield": stats.get("Dividend yield"),
        "source": "Google Finance financials page + overview stats",
    }


def _gf_scrape_financials_page(quote: str, headers: dict[str, str], attempted_urls: list[str]) -> dict[str, Any]:
    url = f"https://www.google.com/finance/quote/{quote}/financials?hl=en"
    attempted_urls.append(url)
    try:
        resp = _requests.get(url, headers=headers, timeout=12)
        if resp.status_code != 200:
            return {"url": url, "status": resp.status_code, "rows": [], "statements": {}}

        soup = _BS(resp.text, "html.parser")
        table_rows: list[dict[str, Any]] = []
        for table in _gf_extract_html_tables(soup):
            table_rows.extend(table.get("rows", []))
        div_rows = _gf_extract_div_financial_rows(soup)

        seen: set[tuple[str, tuple[str, ...]]] = set()
        rows: list[dict[str, Any]] = []
        for row in [*table_rows, *div_rows]:
            label = _gf_clean_text(str(row.get("label") or ""))
            values = [_gf_clean_text(str(v)) for v in (row.get("values") or [])]
            if not label or not values:
                continue
            key = (label.lower(), tuple(values))
            if key in seen:
                continue
            seen.add(key)
            row["label"] = label
            row["values"] = values
            row["numericValues"] = [_gf_number(v) for v in values]
            row["statement"] = _gf_statement_kind(label)
            rows.append(row)

        periods = _gf_extract_periods(rows)
        statements = _gf_rows_by_statement(rows)
        return {
            "url": url,
            "status": resp.status_code,
            "periods": periods,
            "rows": rows[:120],
            "statements": statements,
            "rowCount": len(rows),
        }
    except Exception as exc:
        return {"url": url, "error": str(exc), "rows": [], "statements": {}}


def _scrape_google_finance_safe(ticker: str, raise_on_error: bool = False):
    ticker = ticker.upper().strip()
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9,fr;q=0.8",
        "Cookie": "CONSENT=YES+1",
    }

    last_err = None
    attempted_urls = []
    for symbol, exch, quote in _gf_candidate_quotes(ticker):
        url = f"https://www.google.com/finance/quote/{quote}?hl=en"
        attempted_urls.append(url)
        try:
            resp = _requests.get(url, headers=headers, timeout=10)
            if resp.status_code != 200:
                continue
            
            soup = _BS(resp.text, "html.parser")
            
            price = _gf_first_text(soup, [
                "div.YMlKec.fxKbKc",
                "div.YMlKec",
                "div.N6SYTe",
                'div[jsname="ip75Cb"]',
            ]) or "N/A"
            company_name = _gf_first_text(soup, [
                "div.zzDege",
                "div.PZPZlf",
                "h1",
            ])
            exchange_line = _gf_first_text(soup, [
                "div.TgMHGc",
                "div.e1AOyf",
                "div.ygUjEc",
            ])
            change_text = _gf_first_text(soup, [
                "div.JwB6zf",
                "span.WlRRw",
                "span.P2Luy",
                "div[jsname='Fe7oBc']",
            ])
            
            about = _gf_first_text(soup, [
                "div.u3xNFb",
                "div.bLLb2d",
                "section div[jsname] div",
            ]) or "N/A"
            
            stats = _gf_extract_stats(soup)
            normalized_stats = _gf_normalize_stats(stats)
            news = _gf_extract_news(soup)
            peers = _gf_extract_peers(soup, symbol)
            financials = _gf_scrape_financials_page(quote, headers, attempted_urls)
            financial_rows = financials.get("rows") if isinstance(financials, dict) else []
            earnings = _gf_extract_earnings(
                financial_rows if isinstance(financial_rows, list) else [],
                stats,
            )
                
            if price == "N/A" and not stats and not about:
                continue 

            market_cap = normalized_stats.get("marketCap", {}).get("value")
            pe_ratio = normalized_stats.get("peRatio", {}).get("value")
            dividend_yield = normalized_stats.get("dividendYield", {}).get("value")
            employees = normalized_stats.get("employees", {}).get("value")
                
            return {
                "symbol": symbol,
                "query": ticker,
                "quote": quote,
                "exchange": exch,
                "name": company_name,
                "price": price,
                "priceValue": _gf_number(price),
                "change": change_text,
                "exchangeLine": exchange_line,
                "description": about,
                "stats": stats,
                "normalizedStats": normalized_stats,
                "financials": financials,
                "earnings": earnings,
                "marketCap": market_cap,
                "peRatio": pe_ratio,
                "dividendYield": dividend_yield,
                "employees": employees,
                "news": news,
                "peers": peers,
                "url": url,
                "attemptedUrls": attempted_urls,
                "source": "Google Finance",
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
        except Exception as e:
            last_err = e
            continue
            
    if raise_on_error:
        raise HTTPException(status_code=404, detail={
            "message": f"Google Finance data not found for {ticker}",
            "lastError": str(last_err),
            "attemptedUrls": attempted_urls[:12],
        })
    return {"symbol": ticker, "source": "Google Finance", "attemptedUrls": attempted_urls, "error": str(last_err) if last_err else None}


# ---------------------------------------------------------------------------
# AI Router — Hugging Face Inference API
# ---------------------------------------------------------------------------
ai_router = APIRouter(prefix="/ai", tags=["AI"])

_HF_TOKEN = os.getenv("HF_TOKEN", "")
_HF_HEADERS = lambda: {"Authorization": f"Bearer {_HF_TOKEN}"} if _HF_TOKEN else {}
_HF_API = "https://api-inference.huggingface.co/models"

_cache_ai_sentiment = TTLCache(maxsize=200, ttl=300)   # 5min
_cache_ai_summary   = TTLCache(maxsize=100, ttl=600)   # 10min


def _hf_post(model: str, payload: dict, timeout: int = 30) -> Any:
    """POST to HF Inference API with cold-start retry (model may be loading)."""
    url = f"{_HF_API}/{model}"
    for attempt in range(3):
        r = _requests.post(url, headers=_HF_HEADERS(), json=payload, timeout=timeout)
        if r.status_code == 503:
            # Model loading — wait and retry
            estimated = r.json().get("estimated_time", 20)
            time.sleep(min(float(estimated), 20))
            continue
        r.raise_for_status()
        return r.json()
    raise HTTPException(status_code=503, detail="HF model unavailable after retries")


@ai_router.get("/{symbol}/sentiment")
async def ai_sentiment(symbol: str):
    """
    FinBERT sentiment on the latest news headlines for a ticker.
    Returns per-article scores + an aggregate (positive/negative/neutral).
    """
    sym = symbol.upper().strip()

    def _fetch():
        # Get news from existing endpoint cache
        t = yf.Ticker(sym)
        raw = t.news or []
        headlines = []
        for item in raw[:10]:
            c = item.get("content") or item
            title = c.get("title") or ""
            if title:
                headlines.append(title)

        if not headlines:
            return {"symbol": sym, "headlines": [], "aggregate": None, "articles": []}

        results = _hf_post(
            "ProsusAI/finbert",
            {"inputs": headlines},
            timeout=45,
        )

        articles = []
        counts = {"positive": 0, "negative": 0, "neutral": 0}
        for headline, scores in zip(headlines, results):
            top = max(scores, key=lambda x: x["score"])
            label = top["label"].lower()
            counts[label] = counts.get(label, 0) + 1
            articles.append({
                "headline": headline,
                "sentiment": label,
                "score": round(top["score"], 4),
                "all": {s["label"].lower(): round(s["score"], 4) for s in scores},
            })

        total = sum(counts.values()) or 1
        aggregate = max(counts, key=counts.get)
        return {
            "symbol": sym,
            "aggregate": aggregate,
            "confidence": round(counts[aggregate] / total, 2),
            "counts": counts,
            "articles": articles,
        }

    try:
        return _cached(_cache_ai_sentiment, sym, _fetch, retries=1)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail={"error": str(e), "symbol": sym})


@ai_router.get("/{symbol}/summary")
async def ai_summary(symbol: str):
    """
    AI-generated summary of the company profile using BART.
    Summarizes the longBusinessSummary field from yfinance.
    """
    sym = symbol.upper().strip()

    def _fetch():
        t = yf.Ticker(sym)
        info = t.info or {}
        text = info.get("longBusinessSummary") or info.get("description") or ""
        if not text or len(text) < 100:
            return {"symbol": sym, "summary": text or None, "source": "yfinance_raw"}

        # BART summarization — truncate to 1024 tokens max
        result = _hf_post(
            "facebook/bart-large-cnn",
            {
                "inputs": text[:3000],
                "parameters": {"max_length": 120, "min_length": 40, "do_sample": False},
            },
            timeout=60,
        )
        summary = result[0]["summary_text"] if isinstance(result, list) else text
        return {"symbol": sym, "summary": summary, "original_length": len(text), "source": "bart"}

    try:
        return _cached(_cache_ai_summary, sym, _fetch, retries=1)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail={"error": str(e), "symbol": sym})


@ai_router.get("/{symbol}/analysis")
async def ai_analysis(symbol: str):
    """
    Combined AI analysis: sentiment + summary in one call.
    Used by the Flutter ANALYSE tab.
    """
    sym = symbol.upper().strip()
    cache_key = f"analysis:{sym}"

    def _fetch():
        # Run both in parallel threads
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:
            f_sentiment = ex.submit(_hf_post, "ProsusAI/finbert",
                                    {"inputs": _get_headlines(sym)}, 45)
            f_profile   = ex.submit(_get_profile_text, sym)
            headlines_raw, profile_text = f_sentiment.result(), f_profile.result()

        # Sentiment aggregate
        headlines = _get_headlines(sym)
        sentiment_result = None
        if headlines:
            scores_list = headlines_raw if isinstance(headlines_raw, list) else []
            counts = {"positive": 0, "negative": 0, "neutral": 0}
            for scores in scores_list:
                if isinstance(scores, list):
                    top = max(scores, key=lambda x: x["score"])
                    counts[top["label"].lower()] = counts.get(top["label"].lower(), 0) + 1
            total = sum(counts.values()) or 1
            agg = max(counts, key=counts.get)
            sentiment_result = {"aggregate": agg, "confidence": round(counts[agg] / total, 2), "counts": counts}

        # Summary
        summary = None
        if profile_text and len(profile_text) >= 100:
            res = _hf_post("facebook/bart-large-cnn",
                           {"inputs": profile_text[:3000],
                            "parameters": {"max_length": 120, "min_length": 40, "do_sample": False}},
                           timeout=60)
            summary = res[0]["summary_text"] if isinstance(res, list) else None

        return {"symbol": sym, "sentiment": sentiment_result, "summary": summary}

    try:
        return _cached(_cache_ai_sentiment, cache_key, _fetch, retries=1)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail={"error": str(e), "symbol": sym})


def _get_headlines(sym: str) -> list:
    """Get news headlines reusing the /equities/{sym}/news cache to avoid direct yfinance calls."""
    try:
        # Reuse the existing news cache (same cache used by the /equities/{sym}/news endpoint)
        cached = _cache_news.get(sym)
        if cached is not None:
            articles = cached.get("articles") or []
            return [a["title"] for a in articles[:10] if a.get("title")]

        # Not in cache yet — fetch directly and populate the cache
        t = yf.Ticker(sym)
        raw = t.news or []
        items = []
        headlines = []
        for item in raw[:10]:
            c = item.get("content") or item
            title = c.get("title") or ""
            if title:
                headlines.append(title)
                items.append({"title": title})
        # Warm the news cache so the /news endpoint benefits too
        _cache_news[sym] = {"symbol": sym, "articles": items, "source": "yfinance"}
        return headlines
    except Exception:
        return []


def _get_profile_text(sym: str) -> str:
    """Get company profile text reusing the price/profile cache."""
    try:
        # Try price cache first (same key used by /equities/{sym}/profile)
        cached = _cache_price.get(sym)
        if cached is not None:
            text = cached.get("longBusinessSummary") or cached.get("description") or ""
            if text:
                return text
        # Fallback: direct yfinance call
        info = yf.Ticker(sym).info or {}
        return info.get("longBusinessSummary") or info.get("description") or ""
    except Exception:
        return ""


# --- Register Routers ---
app.include_router(search_router)
app.include_router(equities_router)
app.include_router(market_router)
app.include_router(macro_router)
app.include_router(ai_router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
