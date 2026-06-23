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
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>MasterOps Cloud Platform</title>
        <style>
          body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: #0f172a;
            color: #e5e7eb;
          }

          main {
            max-width: 1100px;
            margin: 0 auto;
            padding: 48px 20px;
          }

          .hero {
            background: linear-gradient(135deg, #1e293b, #111827);
            border: 1px solid #334155;
            border-radius: 18px;
            padding: 32px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.35);
          }

          h1 {
            margin: 0 0 12px;
            font-size: 36px;
          }

          p {
            color: #cbd5e1;
            line-height: 1.6;
          }

          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-top: 28px;
          }

          .card {
            background: #020617;
            border: 1px solid #334155;
            border-radius: 14px;
            padding: 20px;
          }

          .card h2 {
            font-size: 18px;
            margin: 0 0 8px;
          }

          .card a {
            display: inline-block;
            margin-top: 12px;
            color: #38bdf8;
            text-decoration: none;
            font-weight: 700;
          }

          .badge {
            display: inline-block;
            padding: 6px 10px;
            border-radius: 999px;
            background: #064e3b;
            color: #a7f3d0;
            font-size: 13px;
            font-weight: 700;
          }
        </style>
      </head>
      <body>
        <main>
          <section class="hero">
            <span class="badge">K3s + Traefik + TLS + Observability</span>
            <h1>MasterOps Cloud Platform</h1>
            <p>
              Plateforme cloud-native de suivi de parc, conformité, heartbeats
              et incidents. Déployée sur OCI avec Terraform, Ansible, K3s,
              GitHub Actions, Prometheus, Grafana, Jaeger et OpenCost.
            </p>

            <div class="grid">
              <div class="card">
                <h2>Health</h2>
                <p>Endpoint technique utilisé pour vérifier que l'API répond.</p>
                <a href="/health">Ouvrir /health</a>
              </div>

              <div class="card">
                <h2>Metrics</h2>
                <p>Endpoint Prometheus exposant les métriques applicatives.</p>
                <a href="/metrics">Ouvrir /metrics</a>
              </div>

              <div class="card">
                <h2>Assets</h2>
                <p>Liste simulée des équipements suivis par MasterOps.</p>
                <a href="/api/assets">Ouvrir /api/assets</a>
              </div>

              <div class="card">
                <h2>Incidents</h2>
                <p>Incidents ouverts générés autour de la supervision du parc.</p>
                <a href="/api/incidents">Ouvrir /api/incidents</a>
              </div>
            </div>
          </section>
        </main>
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