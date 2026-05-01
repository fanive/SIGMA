FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app

# Default: run HTTP gateway for Flutter clients
CMD ["sh", "-c", "python -m uvicorn data_server:app --host 0.0.0.0 --port ${PORT:-8642}"]
