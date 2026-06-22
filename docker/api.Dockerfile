FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

COPY app/api/requirements.txt ./requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

COPY app/api/ .

EXPOSE 8000

CMD ["opentelemetry-instrument", "gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "main:app"]