# SIGMA Financial Analysis App — Development Skills

## Domain Knowledge

### Technical Analysis Indicators
When implementing or modifying technical analysis features in SIGMA:
1. **RSI (Relative Strength Index)**: Period 14. Oversold < 30, Overbought > 70. Use Wilder's smoothing method.
2. **MACD**: Fast EMA 12, Slow EMA 26, Signal 9. Detect crossovers for buy/sell signals.
3. **Bollinger Bands**: Period 20, 2 standard deviations. %B measures price position within bands.
4. **Moving Averages**: SMA 20/50/200. Golden Cross = SMA50 crosses above SMA200. Death Cross = inverse.
5. **Stochastic**: %K period 14, %D period 3. Oversold < 20, Overbought > 80.
6. **ATR (Average True Range)**: Period 14. Measures volatility. Use for position sizing and stop-loss.
7. **VWAP**: Volume-Weighted Average Price. Institutional benchmark for intraday trading.

### Fundamental Analysis Frameworks
1. **Piotroski F-Score** (0-9): 9 binary criteria covering profitability, leverage, liquidity, and operating efficiency.
2. **Altman Z-Score**: Bankruptcy prediction. Safe > 2.99, Grey 1.81-2.99, Distress < 1.81.
3. **Graham Number**: √(22.5 × EPS × Book Value per Share). Margin of safety > 30% = undervalued.
4. **DCF Valuation**: Project FCF for 10 years with fading growth, terminal value with perpetuity growth model.
5. **PEG Ratio**: P/E divided by earnings growth rate. < 1 suggests undervalued relative to growth.

### Data Sources Priority
1. **Yahoo Finance** (primary): Real-time quotes, historical OHLCV, financial statements, analyst recommendations
2. **Finnhub** (real-time): WebSocket price streaming, company news, insider transactions
3. **FMP** (fundamental): Financial statements, DCF, key metrics, earnings calendar
4. **Twelve Data** (technical): Pre-calculated technical indicators, intraday data
5. **Ollama Cloud** (AI): Synthesis, sentiment analysis, report generation

### Design System — Quiet Luxury
- **Dark palette**: Piano Black (#0D0D0D), warm neutrals, champagne gold (#BFA36D) accent
- **Light palette**: Warm ivory (#F8F5F1), cream cards, darker gold (#8C7549)
- **Typography**: Outfit (display), Inter (body), JetBrains Mono (financial data)
- **Semantics**: Sage green (#5B9A6B) positive, Dusty rose (#C4706E) negative, Steel blue (#7B94A8) neutral
- **Principles**: Understatement, generous whitespace, subtle animations (300ms easeOutCubic)

### Internationalization
- Uses Flutter gen-l10n with ARB files in `lib/l10n/`
- Template: `app_en.arb` with ~200 keys
- Supported: EN, FR, ES, PT, DE, IT, JA, ZH, KO, AR
- Device language auto-detection enabled
- User override stored in SharedPreferences as language code

### AI Provider Architecture
- Factory pattern via `AIProviderFactory`
- Providers: Gemini, OpenRouter, Groq, GitHub Copilot/OpenAI, Ollama Cloud
- Ollama uses fallback chain (4 models max) with per-model timeout
- Semaphore limits concurrent Ollama requests to 2
- All AI keys stored in `.env`
