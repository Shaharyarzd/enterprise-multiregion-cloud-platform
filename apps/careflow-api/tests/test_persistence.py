import json
import os
import pathlib
import sys
import tempfile
import types
import unittest
from unittest import mock

APP_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP_DIR))
from persistence import (
    Database,
    DatabaseConfigurationError,
    DatabaseUnavailable,
    SecretFileConfigProvider,
    default_pool_factory,
)


class FakeResult:
    def __init__(self, rows):
        self.rows = rows

    def fetchall(self):
        return self.rows

    def fetchone(self):
        return self.rows[0] if self.rows else None


class FakeConnection:
    def __init__(self, fail=False, migration_applied=True):
        self.fail = fail
        self.migration_applied = migration_applied
        self.committed = False
        self.executed = []

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def execute(self, sql, _parameters=None):
        self.executed.append(sql)
        if self.fail:
            raise RuntimeError("password=must-never-escape")
        if "SELECT version" in sql:
            rows = [("001_synthetic_appointments.sql",)] if self.migration_applied else []
            return FakeResult(rows)
        if "SELECT 1" in sql:
            return FakeResult([(1,)])
        if "FROM appointments" in sql:
            return FakeResult([("apt-demo-001", "patient-demo-001", "scheduled")])
        return FakeResult([])

    def commit(self):
        self.committed = True


class ConnectionContext:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        return self.connection

    def __exit__(self, *_args):
        return False


class FakePool:
    def __init__(self, fail=False, migration_applied=True):
        self.connection_instance = FakeConnection(fail, migration_applied)
        self.closed = False

    def connection(self, timeout=None):
        return ConnectionContext(self.connection_instance)

    def close(self):
        self.closed = True


class PersistenceTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.secret_path = pathlib.Path(self.temp_dir.name) / "database.json"
        self.write_secret("first")

    def tearDown(self):
        self.temp_dir.cleanup()

    def write_secret(self, password):
        self.secret_path.write_text(json.dumps({
            "host": "db.example.invalid",
            "port": 5432,
            "dbname": "careflow",
            "username": "careflow_admin",
            "password": password,
        }))

    def test_provider_requires_tls_and_complete_secret(self):
        provider = SecretFileConfigProvider(self.secret_path, sslmode="disable")
        with self.assertRaises(DatabaseConfigurationError):
            provider.load()

    def test_insecure_database_is_explicitly_local_only(self):
        provider = SecretFileConfigProvider(self.secret_path, sslmode="disable")
        with mock.patch.dict(os.environ, {"ALLOW_INSECURE_LOCAL_DATABASE": "true"}):
            self.assertEqual(provider.load()["sslmode"], "disable")

    def test_pool_rotates_when_mounted_secret_changes(self):
        pools = []

        def factory(_config, _minimum, _maximum, _timeout):
            pool = FakePool()
            pools.append(pool)
            return pool

        database = Database(SecretFileConfigProvider(self.secret_path), pool_factory=factory)
        database.check_readiness()
        self.write_secret("rotated")
        database.check_readiness()
        self.assertEqual(len(pools), 2)
        self.assertTrue(pools[0].closed)

    def test_default_pool_maps_secret_username_to_psycopg_user(self):
        pool_class = mock.Mock(return_value=object())
        fake_module = types.SimpleNamespace(ConnectionPool=pool_class)
        config = {
            "host": "db.example.invalid",
            "port": 5432,
            "dbname": "careflow",
            "username": "careflow_admin",
            "password": "not-a-real-secret",
            "sslmode": "require",
        }
        with mock.patch.dict(sys.modules, {"psycopg_pool": fake_module}):
            default_pool_factory(config, 1, 5, 3)

        connection_kwargs = pool_class.call_args.kwargs["kwargs"]
        self.assertEqual(connection_kwargs["user"], "careflow_admin")
        self.assertNotIn("username", connection_kwargs)
        self.assertIn("username", config)

    def test_query_maps_only_synthetic_fields(self):
        database = Database(
            SecretFileConfigProvider(self.secret_path),
            pool_factory=lambda *_args: FakePool(),
        )
        self.assertEqual(database.list_appointments(), [{
            "id": "apt-demo-001",
            "patient_id": "patient-demo-001",
            "status": "scheduled",
        }])

    def test_pending_migration_is_applied_and_committed(self):
        pool = FakePool(migration_applied=False)
        database = Database(
            SecretFileConfigProvider(self.secret_path),
            pool_factory=lambda *_args: pool,
        )
        database.check_readiness()
        self.assertTrue(pool.connection_instance.committed)
        self.assertTrue(any("CREATE TABLE patients" in sql for sql in pool.connection_instance.executed))

    def test_driver_error_is_wrapped_without_credentials(self):
        database = Database(
            SecretFileConfigProvider(self.secret_path),
            pool_factory=lambda *_args: FakePool(fail=True),
        )
        with self.assertRaises(DatabaseUnavailable) as raised:
            database.check_readiness()
        self.assertNotIn("password", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
