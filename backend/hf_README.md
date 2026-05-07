---
title: SIGMA yfinance API
emoji: 📈
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

# SIGMA yfinance Gateway

FastAPI backend for the SIGMA Flutter app.  
Serves market data (quotes, history, search, financials) via yfinance.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Health check |
| GET | `/search?q=AAPL` | Ticker search |
| GET | `/quote/{symbol}` | Real-time quote |
| GET | `/quotes?symbols=AAPL,TSLA` | Batch quotes |
| GET | `/history/{symbol}` | Price history |
| GET | `/profile/{symbol}` | Company profile |
| GET | `/financials/{symbol}` | Income / balance / cash flow |
| GET | `/analysis/{symbol}` | Analyst ratings |
