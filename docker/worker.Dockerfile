FROM python:3.12-slim

RUN useradd \
    --system \
    --uid 10002 \
    --create-home \
    worker

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

COPY app/worker/requirements.txt ./requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=worker:worker app/worker ./worker

USER worker

CMD ["python", "-m", "worker.simulator"]