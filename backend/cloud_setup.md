# Cloud deployment (Render Web API)

This project is deployed as an HTTP API so the Flutter app can query it directly.

## Recommended setup: Render Web Service

Current storage is SQLite (`backend/data/market_data.db`).
For production durability, migrate to Postgres later because Render filesystems are ephemeral.

## Quick deploy on Render

1. Push repository to GitHub.
2. In Render, create a **Blueprint** from repository.
3. Render reads `backend/render.yaml`.
4. It builds from `backend/Dockerfile`.
5. Service runs uvicorn on Render port.

After deploy, validate:

```bash
https://<your-render-service>.onrender.com/
https://<your-render-service>.onrender.com/search?q=tesla
```

## Flutter configuration

In project `.env`, set:

```env
YF_BACKEND_URL=https://<your-render-service>.onrender.com
```

Then restart Flutter app completely.

## Local Docker test

From repository root:

```bash
docker build -t sigma-yf-api ./backend
docker run --rm -p 8642:8642 sigma-yf-api
```

Test locally:

```bash
http://127.0.0.1:8642/
http://127.0.0.1:8642/search?q=tesla
```
