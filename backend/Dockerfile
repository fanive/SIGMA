FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app

# Hugging Face Spaces requires port 7860
EXPOSE 7860

# Default port 7860 (HF Spaces); Render injects PORT automatically
CMD ["sh", "-c", "python -m uvicorn data_server:app --host 0.0.0.0 --port ${PORT:-7860}"]
