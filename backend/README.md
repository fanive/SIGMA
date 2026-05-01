# SIGMA yfinance Module (No FastAPI)

This backend is now a pure Python data collector based on yfinance.
It stores data in a local SQLite database and can run once or on a schedule.

## What it does

- Collects quotes
- Collects OHLCV history
- Stores fundamentals snapshots
- Stores options chain snapshots
- Stores latest news snapshots

## Folder layout

- `run_collector.py`: CLI entry point
- `watchlist.txt`: default symbols list
- `data/market_data.db`: SQLite database (auto-created)
- `yf_core/`: collector module code

## Quick start

From `backend/`:

```bat
pip install -r requirements.txt
python run_collector.py init
python run_collector.py once --symbols-file watchlist.txt
```

Run scheduled collection every 5 minutes:

```bat
python run_collector.py schedule --symbols-file watchlist.txt --interval-minutes 5
```

## Useful commands

Collect specific symbols once:

```bat
python run_collector.py once --symbols AAPL,MSFT,NVDA
```

Change history settings:

```bat
python run_collector.py once --symbols-file watchlist.txt --history-period 6mo --history-interval 1d
```

Verbose logs:

```bat
python run_collector.py once --symbols AAPL --verbose
```

Validate data completeness (quote/history/fundamentals/options/news):

```bat
python validate_yfinance.py --symbols AAPL,MSFT,NVDA
```

## Main tables

- `quotes`: latest quote per symbol
- `ohlcv`: historical candles
- `fundamentals_snapshots`: point-in-time fundamentals data
- `options_snapshots`: options chains by expiration
- `news_snapshots`: latest news records

## Cloud deployment

- Docker web API config: `Dockerfile`
- Render web blueprint: `render.yaml`
- Deployment guide: `cloud_setup.md`

Important: SQLite is fine for local use, but production cloud should use Postgres because worker filesystems are ephemeral.

## Local phone mode (fix Yahoo 429)

If your phone app gets empty search/results due Yahoo rate limits, run the local gateway on your machine:

```bat
python -m pip install -r requirements.txt
python -m uvicorn data_server:app --host 0.0.0.0 --port 8642
```

Then in app `.env`, set:

```env
YF_BACKEND_URL=http://<YOUR_PC_LOCAL_IP>:8642
```

Example:

```env
YF_BACKEND_URL=http://192.168.1.35:8642
```
