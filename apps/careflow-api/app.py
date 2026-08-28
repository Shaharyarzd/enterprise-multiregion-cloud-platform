import json
import os
import signal
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

from persistence import Database, DatabaseUnavailable

START_TIME = time.time()
DATABASE = Database.from_environment()


class Metrics:
    """Small Prometheus exposition helper; no separate metrics framework is needed."""

    BUCKETS = (0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)

    def __init__(self):
        self._lock = threading.Lock()
        self._requests = {}
        self._latencies = {}
        self._database_healthy = 0

    def observe(self, path, status, duration):
        route_name = path if path in {
            "/healthz", "/readyz", "/api/v1/appointments", "/metadata"
        } else "not_found"
        key = (route_name, str(status))
        with self._lock:
            self._requests[key] = self._requests.get(key, 0) + 1
            values = self._latencies.setdefault(route_name, [])
            values.append(duration)
            if len(values) > 10000:
                del values[:5000]

    def set_database_healthy(self, healthy):
        with self._lock:
            self._database_healthy = 1 if healthy else 0

    def render(self):
        with self._lock:
            request_counts = dict(self._requests)
            latencies = {key: tuple(value) for key, value in self._latencies.items()}
            database_healthy = self._database_healthy

        lines = [
            "# HELP careflow_http_requests_total HTTP requests handled by route and status.",
            "# TYPE careflow_http_requests_total counter",
        ]
        for (path, status), count in sorted(request_counts.items()):
            lines.append(
                'careflow_http_requests_total{method="GET",path="%s",status="%s"} %d'
                % (path, status, count)
            )

        lines.extend([
            "# HELP careflow_http_request_duration_seconds HTTP request latency.",
            "# TYPE careflow_http_request_duration_seconds histogram",
        ])
        for path, values in sorted(latencies.items()):
            cumulative = 0
            for bucket in self.BUCKETS:
                cumulative = sum(1 for value in values if value <= bucket)
                lines.append(
                    'careflow_http_request_duration_seconds_bucket{method="GET",path="%s",le="%s"} %d'
                    % (path, bucket, cumulative)
                )
            lines.append(
                'careflow_http_request_duration_seconds_bucket{method="GET",path="%s",le="+Inf"} %d'
                % (path, len(values))
            )
            lines.append(
                'careflow_http_request_duration_seconds_sum{method="GET",path="%s"} %.9f'
                % (path, sum(values))
            )
            lines.append(
                'careflow_http_request_duration_seconds_count{method="GET",path="%s"} %d'
                % (path, len(values))
            )

        lines.extend([
            "# HELP careflow_database_dependency_healthy Whether the last PostgreSQL check succeeded.",
            "# TYPE careflow_database_dependency_healthy gauge",
            "careflow_database_dependency_healthy %d" % database_healthy,
            "# HELP careflow_process_uptime_seconds Process uptime.",
            "# TYPE careflow_process_uptime_seconds gauge",
            "careflow_process_uptime_seconds %d" % int(time.time() - START_TIME),
            "",
        ])
        return "\n".join(lines).encode()


METRICS = Metrics()


def route(path, database=None):
    """Return (status_code, content_type, body_bytes) for a request path."""
    database = database or DATABASE

    if path == "/healthz":
        return 200, "application/json", _json({"status": "ok"})

    if path == "/readyz":
        if os.getenv("FORCE_READINESS_FAILURE", "false").lower() == "true":
            METRICS.set_database_healthy(False)
            return 503, "application/json", _json({
                "status": "not_ready", "dependency": "forced_failure"
            })
        try:
            database.check_readiness()
            METRICS.set_database_healthy(True)
            return 200, "application/json", _json({
                "status": "ready", "service": "careflow-api", "database": "ok"
            })
        except DatabaseUnavailable:
            METRICS.set_database_healthy(False)
            return 503, "application/json", _json({
                "status": "not_ready", "dependency": "database"
            })

    if path == "/api/v1/appointments":
        try:
            appointments = database.list_appointments()
            METRICS.set_database_healthy(True)
            return 200, "application/json", _json({
                "data": appointments, "synthetic": True
            })
        except DatabaseUnavailable:
            METRICS.set_database_healthy(False)
            return 503, "application/json", _json({
                "error": "dependency_unavailable", "dependency": "database"
            })

    if path == "/metadata":
        return 200, "application/json", _json({
            "service": "careflow-api",
            "version": os.getenv("APP_VERSION", "dev"),
            "environment": os.getenv("ENVIRONMENT", "local"),
            "uptime_seconds": int(time.time() - START_TIME),
        })

    if path == "/metrics":
        return 200, "text/plain; version=0.0.4", METRICS.render()

    return 404, "application/json", _json({"error": "not_found"})


def _json(payload):
    return json.dumps(payload, separators=(",", ":")).encode()


class Handler(BaseHTTPRequestHandler):
    server_version = "CareFlowPortfolio/0.2"

    def do_GET(self):
        path = urlparse(self.path).path
        started = time.monotonic()
        status, content_type, body = route(path)
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        if path != "/metrics":
            METRICS.observe(path, status, time.monotonic() - started)

    def log_message(self, fmt, *args):
        print(json.dumps({"message": fmt % args, "service": "careflow-api"}), flush=True)


def run():
    port = int(os.getenv("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)

    def stop(_signum, _frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    print(json.dumps({"message": "server_started", "port": port}), flush=True)
    try:
        server.serve_forever()
    finally:
        DATABASE.close()
        server.server_close()


if __name__ == "__main__":
    run()
