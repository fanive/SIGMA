from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import pandas as pd
import yfinance as yf
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="SIGMA yfinance Gateway", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


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
    return {"status": "ok", "service": "yfinance-gateway",
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


@app.get("/quote/{symbol}")
async def quote(symbol: str):
    """Full ticker data: price, profile, valuation, financials, analysis, ownership, news, options, events."""
    sym = symbol.upper().strip()
    try:
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

        news_raw = []
        try:
            for item in (t.news or [])[:20]:
                news_raw.append({
                    "title": item.get("title"),
                    "publisher": item.get("publisher"),
                    "link": item.get("link") or (item.get("canonicalUrl") or {}).get("url"),
                    "publishedAt": _safe(item.get("providerPublishTime")),
                    "type": item.get("type"),
                })
        except Exception:
            pass

        options_data: dict = {"expirations": [], "calls": [], "puts": []}
        try:
            expirations = list(t.options or [])
            options_data["expirations"] = expirations
            if expirations:
                chain = t.option_chain(expirations[0])
                options_data["selectedExpiration"] = expirations[0]
                options_data["calls"] = _df_to_list(chain.calls, limit=100)
                options_data["puts"] = _df_to_list(chain.puts, limit=100)
        except Exception:
            pass

        analysis_data: dict = {}
        try:
            analysis_data = {
                "analystPriceTargets": _clean(t.analyst_price_targets),
                "recommendations": _df_to_list(t.recommendations, limit=20),
                "upgradesDowngrades": _df_to_list(t.upgrades_downgrades, limit=30),
                "earningsHistory": _df_to_list(t.earnings_history, limit=12),
                "earningsEstimate": _df_to_list(t.earnings_estimate),
                "revenueEstimate": _df_to_list(t.revenue_estimate),
                "epsTrend": _df_to_list(t.eps_trend),
                "growthEstimates": _df_to_list(t.growth_estimates),
            }
        except Exception:
            pass

        ownership_data: dict = {}
        try:
            ownership_data = {
                "majorHolders": _df_to_list(t.major_holders),
                "institutionalHolders": _df_to_list(t.institutional_holders, limit=25),
                "mutualFundHolders": _df_to_list(t.mutualfund_holders, limit=25),
                "insiderTransactions": _df_to_list(t.insider_transactions, limit=30),
                "insiderRoster": _df_to_list(t.insider_roster_holders, limit=20),
            }
        except Exception:
            pass

        financials_data: dict = {}
        try:
            financials_data = {
                "quarterlyIncomeStatement": _stmt_to_list(t.quarterly_income_stmt),
                "quarterlyBalanceSheet": _stmt_to_list(t.quarterly_balance_sheet),
                "quarterlyCashFlow": _stmt_to_list(t.quarterly_cashflow),
                "annualIncomeStatement": _stmt_to_list(t.income_stmt),
                "annualBalanceSheet": _stmt_to_list(t.balance_sheet),
                "annualCashFlow": _stmt_to_list(t.cashflow),
            }
        except Exception:
            pass

        events_data: dict = {}
        try:
            events_data = {
                "calendar": _clean(t.calendar),
                "dividends": _series_to_list(t.dividends, value_key="dividend", limit=50),
                "splits": _series_to_list(t.splits, value_key="split", limit=50),
            }
        except Exception:
            pass

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
            "financials": financials_data,
            "analysis": analysis_data,
            "ownership": ownership_data,
            "events": events_data,
            "options": options_data,
            "news": news_raw,
            "source": "yfinance",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"quote failed for {sym}: {e}")


@app.get("/multi-quote")
async def multi_quote(symbols: str = Query(..., description="Comma separated symbols")):
    """Lightweight price-only snapshot for a list of tickers."""
    sym_list = [s.strip().upper() for s in symbols.split(",") if s.strip()][:50]
    out = []
    for sym in sym_list:
        try:
            t = yf.Ticker(sym)
            fi = t.fast_info
            price = _num(fi.get("lastPrice") if fi else 0)
            prev = _num(fi.get("previousClose") if fi else 0)
            change = price - prev if prev > 0 else 0
            change_pct = (change / prev * 100) if prev > 0 else 0
            out.append({"symbol": sym, "price": price, "change": change,
                        "changesPercentage": change_pct, "source": "yfinance"})
        except Exception:
            continue
    return out


@app.get("/history/{symbol}")
async def history(symbol: str, range: str = "1mo", interval: str = "1d", prepost: bool = False):
    """OHLCV history. period/interval follow yfinance conventions."""
    sym = symbol.upper().strip()
    try:
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
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"history failed for {sym}: {e}")


@app.get("/intraday/{symbol}")
async def intraday(symbol: str, interval: str = "5m", range: str = "1d", prepost: bool = True):
    """Intraday bars. Delegates to /history with prepost=True."""
    return await history(symbol=symbol, range=range, interval=interval, prepost=prepost)


@app.get("/macro")
async def macro():
    """Global macro snapshot: bonds, DXY, gold, oil, VIX, major indices, BTC."""
    symbols = {
        "^TNX": "tnx", "DX-Y.NYB": "dxy", "GC=F": "gold", "CL=F": "oil",
        "^VIX": "vix", "^GSPC": "sp500", "^NDX": "nasdaq100",
        "^DJI": "dow", "BTC-USD": "bitcoin",
    }
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
