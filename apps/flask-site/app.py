import os
from datetime import datetime

from flask import Flask, jsonify

app = Flask(__name__)

tenant_name = os.environ.get("TENANT_NAME", "unknown")
request_count = 0
start_time = datetime.utcnow()


@app.route("/")
def index():
    global request_count
    request_count += 1
    return jsonify(
        message=f"Hello from the Flask tenant site for {tenant_name}!",
        timestamp=datetime.utcnow().isoformat() + "Z",
        requestCount=request_count,
    )


@app.route("/healthz")
def healthz():
    return "ok", 200


@app.route("/readyz")
def readyz():
    if not tenant_name:
        return "tenant name missing", 503
    return "ready", 200


@app.route("/metrics")
def metrics():
    uptime_seconds = int((datetime.utcnow() - start_time).total_seconds())
    lines = [
        "# HELP tenant_requests_total Total HTTP requests to the root endpoint",
        "# TYPE tenant_requests_total counter",
        f'tenant_requests_total{{tenant="{tenant_name}"}} {request_count}',
        "# HELP tenant_uptime_seconds Application uptime in seconds",
        "# TYPE tenant_uptime_seconds gauge",
        f'tenant_uptime_seconds{{tenant="{tenant_name}"}} {uptime_seconds}',
    ]
    response = app.response_class("\n".join(lines), mimetype="text/plain; version=0.0.4")
    return response, 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
