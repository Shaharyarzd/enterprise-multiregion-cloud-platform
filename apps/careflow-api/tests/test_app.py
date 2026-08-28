import importlib.util
import json
import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

APP_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP_DIR))
spec = importlib.util.spec_from_file_location("careflow_app", APP_DIR / "app.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StubDatabase:
    def __init__(self, healthy=True):
        self.healthy = healthy

    def check_readiness(self):
        if not self.healthy:
            raise module.DatabaseUnavailable("hidden driver detail")

    def list_appointments(self):
        if not self.healthy:
            raise module.DatabaseUnavailable("hidden driver detail")
        return [{"id": "apt-demo-001", "patient_id": "patient-demo-001", "status": "scheduled"}]


class ApiTest(unittest.TestCase):
    def test_liveness_does_not_depend_on_database(self):
        status, content_type, body = module.route("/healthz", StubDatabase(False))
        self.assertEqual(status, 200)
        self.assertEqual(content_type, "application/json")
        self.assertEqual(json.loads(body)["status"], "ok")

    def test_readiness_verifies_database(self):
        status, _, body = module.route("/readyz", StubDatabase(False))
        self.assertEqual(status, 503)
        self.assertEqual(json.loads(body)["dependency"], "database")

    def test_synthetic_appointments_come_from_repository(self):
        status, _, body = module.route("/api/v1/appointments", StubDatabase())
        payload = json.loads(body)
        self.assertEqual(status, 200)
        self.assertTrue(payload["synthetic"])
        self.assertEqual(payload["data"][0]["patient_id"], "patient-demo-001")

    def test_database_failure_is_graceful_and_redacted(self):
        status, _, body = module.route("/api/v1/appointments", StubDatabase(False))
        self.assertEqual(status, 503)
        self.assertNotIn("driver", body.decode())

    def test_metrics_expose_operational_signals(self):
        module.METRICS.observe("/readyz", 503, 0.12)
        module.METRICS.set_database_healthy(False)
        status, content_type, body = module.route("/metrics", StubDatabase())
        text = body.decode()
        self.assertEqual(status, 200)
        self.assertIn("text/plain", content_type)
        self.assertIn("careflow_http_requests_total", text)
        self.assertIn("careflow_http_request_duration_seconds_bucket", text)
        self.assertIn("careflow_database_dependency_healthy 0", text)

    def test_forced_readiness_failure_supports_rollback_drill(self):
        with mock.patch.dict(os.environ, {"FORCE_READINESS_FAILURE": "true"}):
            status, _, body = module.route("/readyz", StubDatabase())
        self.assertEqual(status, 503)
        self.assertEqual(json.loads(body)["dependency"], "forced_failure")


if __name__ == "__main__":
    unittest.main()
