FROM python:3.12-slim AS builder
WORKDIR /build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
COPY app/requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime
RUN useradd --system --uid 10001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/api ./api
ENV PYTHONUNBUFFERED=1 PORT=5000
LABEL org.opencontainers.image.source="https://github.com/Shvwn9/cloudops-homelab-platform"
USER appuser
CMD ["python", "-m", "api.main"]
