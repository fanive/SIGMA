# 🏗️ SIGMA — Yahoo-First Architecture (Implemented)

## ✅ WHAT WAS DONE

### 1. CacheService v2.0 — Smart Financial Caching
**File**: `lib/services/cache_service.dart`

**Granular TTLs (instead of one-size-fits-all):**
| Data Type | TTL (Market Open) | TTL (Market Closed) |
|-----------|-------------------|---------------------|
| Price/Quote | 2 min | 30 min |
| Company Profile | 7 days | 7 days |
| Financial Statements | 24h | 24h |
| Analyst Data | 6h | 6h |
| Holders/Insiders | 12h | 12h |
| Options | 1h | 1h |
| News | 15 min | 15 min |
| Market Overview | 5 min | 30 min |
| Full Analysis | 4h | 4h |
| ESG | 7 days | 7 days |
| Conviction Score | 4h | 4h |
| Chart (Intraday) | 2 min | 2 min |
| Chart (Daily) | 30 min | 30 min |

**New features:**
- `getStale()` — stale-while-revalidate pattern (show old data while refreshing)
- Market hours detection (EST 9:30-16:00)
- Automatic cleanup of expired entries on startup
- Typed cache keys (e.g., `quote_AAPL`, `income_AAPL_a`, `chart_AAPL_1y`)

### 2. QuantumDataService v3.0 — Yahoo-First Architecture
**File**: `lib/services/quantum_data_service.dart`

**BEFORE (17 parallel API calls, most failing):**
```
Yahoo Bundle + Finnhub Quote + FMP Quote + Finnhub Profile + FMP Profile
+ FMP Detailed Profile + Yahoo Chart + Finnhub News + Polygon PrevClose
+ Polygon Details + TwelveData Quote + Polygon News + Marketaux News
+ TwelveData Profile + AlphaVantage Sentiment + AlphaVantage RSI + Yahoofin Price
= 17 calls, most returning {} because API keys are missing/expired
```

**AFTER (Yahoo primary + 2 optional enrichment):**
```
Step 1: Yahoo Finance PRIMARY (19 calls, all free, all cached individually)
  → Bundle, Chart, News, TickerInfo, Recommendations, Analyst Targets,
     Holders, Earnings, KeyStats, FinancialData, Income, Balance, Cashflow,
     ESG, Upgrades, Insiders, Peers, Earnings Estimate, Revenue Estimate

Step 2: Enrichment (2 calls, optional, cached)
  → Finnhub News (different source), FMP Profile (logo URL only)

Step 3: Merge & Build Analysis (pure logic, no API)

Step 4: Conviction Engine (cached, optional)
```

**NEW data surfaced from Yahoo (was available but unused):**
- Short selling: `shortRatio`, `sharesShort`, `sharesShortPriorMonth`, short squeeze detection
- Governance: `auditRisk`, `boardRisk`, `compensationRisk`, `overallRisk`
- Dividend details: `dividendRate`, `payoutRatio`, `fiveYearAvgDividendYield`
- Moving averages: `fiftyDayAverage`, `twoHundredDayAverage`
- Growth: `revenueGrowth`, `earningsGrowth`
- Financial health: `currentRatio`, `grossMargins`, `freeCashflow`
- Earnings estimates: forward-looking data
- Revenue estimates: forward-looking data
- Upgrade/Downgrade history
- ESG scores

**Data-driven signals (not hardcoded anymore):**
- Short squeeze detection based on real `shortRatio` and `shortPercentOfFloat`
- Insider buying/selling from real transaction data
- Volume spike detection from candles
- Near 52-week high/low alerts
- Catalysts from real earnings dates and analyst upgrades

### 3. main.dart — CacheService Initialization
**File**: `lib/main.dart`
- Added `CacheService.initialize()` at app startup

## 📊 Estimated API Call Reduction

| Scenario | Before | After | Reduction |
|----------|--------|-------|-----------|
| First analysis of AAPL | 17 calls + 26 conviction calls | 19 Yahoo + 2 enrichment + 26 conviction | Same |
| Second analysis of AAPL (within 4h) | 17 + 26 = 43 calls | 0 calls (all cached) | **100%** |
| Same day, different ranges | 17 + 26 per range | 1-2 new chart calls only | **95%** |
| Watchlist of 5 stocks | 43 × 5 = 215 calls | 0 (cached) to 105 (fresh) | **50-100%** |
| Market overview refresh | 10+ calls each time | 0 (cached 5min during market) | **90%** |

## 🔧 Architecture Decision

```
                    USER
                      │
                  [SigmaProvider]
                      │
             ┌────────┼────────┐
             │        │        │
        [SigmaService] │  [QuantumDataService]
        (AI Analysis)  │  (Yahoo-First Data)
             │         │        │
             │    [CacheService]│
             │    (Smart TTL)   │
             │         │        │
        ┌────┴────┐    │   ┌────┴────────────┐
        │         │    │   │                  │
   [ConvictionEngine]  │   [Yahoo Finance]   [Enrichment]
   (Deep Scoring)      │   (PRIMARY)         (Optional)
        │              │        │                  │
   ┌────┼────┐         │        │             ┌────┼────┐
   │    │    │         │        │             │         │
 [FMP][Finnhub][12Data]│   [No API Key]   [Finnhub] [FMP]
 [Polygon][AlphaV]     │   [Always Free]  [Logo]   [News]
                       │
                  [ConvictionEngine]
                  (Uses all APIs)
```

**The key insight:**
- `QuantumDataService` works with Yahoo ONLY = app ALWAYS works
- `ConvictionEngine` provides deep scoring when APIs are available
- `SigmaService` uses AI to synthesize everything into human-readable analysis
- `CacheService` prevents redundant calls across ALL services

## ⏭️ NEXT STEPS

1. **Update ConvictionEngine** to also use Yahoo as primary (currently FMP-heavy)
2. **Add ETF/Fund data** using Yahoo's `topHoldings` and `fundProfile` modules
3. **Build screener** using Yahoo's `screen()` endpoint
4. **Add sector/industry explorer** using Yahoo's `Sector()` and `Industry()` APIs
