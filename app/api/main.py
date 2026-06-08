# app/api/main.py
from flask import (
    Flask,
    jsonify,
    request,
    render_template_string,
    redirect,
    url_for,
)
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)
import time

app = Flask(__name__)

REQUESTS = Counter(
    "masterops_http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status"],
)

LATENCY = Histogram(
    "masterops_http_request_duration_seconds",
    "HTTP latency",
    ["path"],
)


@app.before_request
def before_request():
    request._start = time.perf_counter()


@app.after_request
def after_request(response):
    duration = time.perf_counter() - getattr(
        request,
        "_start",
        time.perf_counter(),
    )

    LATENCY.labels(request.path).observe(duration)

    REQUESTS.labels(
        request.method,
        request.path,
        response.status_code,
    ).inc()

    return response


@app.route("/")
def index():
    return redirect(url_for("ui"))


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {
        "Content-Type": CONTENT_TYPE_LATEST
    }


@app.route("/ui")
def ui():
    return render_template_string("""
    <!doctype html>
    <html lang="fr">
      <head>
        <meta charset="utf-8">
        <title>MasterOps Cloud Platform</title>
      </head>
      <body>
        <h1>MasterOps Cloud Platform</h1>

        <p>
          Plateforme de suivi de parc, conformité et incidents.
        </p>

        <ul>
          <li><a href="/health">Health</a></li>
          <li><a href="/metrics">Metrics</a></li>
          <li><a href="/api/assets">Assets</a></li>
          <li><a href="/api/incidents">Incidents</a></li>
        </ul>
      </body>
    </html>
    """)


@app.route("/api/assets")
def assets():
    return jsonify([
        {
            "hostname": "VM-LINUX-CORE-001",
            "role": "server",
            "env": "prod",
        },
        {
            "hostname": "POSTE-WIN-FACTORY-042",
            "role": "workstation",
            "env": "corp",
        },
    ])


@app.route("/api/incidents")
def incidents():
    return jsonify([
        {
            "id": 1,
            "severity": "warning",
            "title": "No heartbeat > 15 min",
            "asset": "POSTE-WIN-FACTORY-042",
        }
    ])