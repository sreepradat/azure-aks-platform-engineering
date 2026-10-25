"""Small Flask service used to demonstrate the platform pipeline.

Endpoints
---------
/         service metadata (version, environment, whether the Key Vault secret is mounted)
/healthz  liveness probe
/readyz   readiness probe
/metrics  Prometheus metrics
"""

import os
import time
from pathlib import Path

from flask import Flask, Response, g, jsonify, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

APP_VERSION = os.getenv("APP_VERSION", "dev")
APP_ENV = os.getenv("APP_ENV", "local")

# Azure Key Vault secrets are mounted here by the Secrets Store CSI driver.
SECRET_PATH = Path(os.getenv("SECRET_MOUNT_PATH", "/mnt/secrets")) / "app-message"

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["endpoint"],
)


def create_app() -> Flask:
    app = Flask(__name__)

    @app.before_request
    def start_timer() -> None:
        g.start_time = time.perf_counter()

    @app.after_request
    def record_metrics(response: Response) -> Response:
        endpoint = request.url_rule.rule if request.url_rule else "unmatched"
        started = g.get("start_time", time.perf_counter())
        REQUEST_COUNT.labels(request.method, endpoint, response.status_code).inc()
        REQUEST_LATENCY.labels(endpoint).observe(time.perf_counter() - started)
        return response

    @app.get("/")
    def index():
        return jsonify(
            service="sample-app",
            version=APP_VERSION,
            environment=APP_ENV,
            secret_loaded=SECRET_PATH.is_file(),
        )

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    @app.get("/readyz")
    def readyz():
        return jsonify(status="ready")

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    return app


app = create_app()
