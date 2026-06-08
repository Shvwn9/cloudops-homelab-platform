FROM python:3.12-slim
RUN useradd --system --uid 10002 worker
WORKDIR /app
COPY app/requirements.txt .
RUN pip install -r requirements.txt
COPY app/worker ./worker
USER worker
CMD ["python", "-m", "worker.simulator"]
