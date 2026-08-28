import hashlib
import json
import os
import pathlib
import threading


class DatabaseUnavailable(RuntimeError):
    """Safe boundary error: callers never receive credentials or driver details."""


class DatabaseConfigurationError(DatabaseUnavailable):
    pass


class SecretFileConfigProvider:
    REQUIRED_KEYS = ("host", "port", "dbname", "username", "password")

    def __init__(self, path, sslmode="verify-full", sslrootcert=None):
        self.path = pathlib.Path(path)
        self.sslmode = sslmode
        self.sslrootcert = sslrootcert

    def load(self):
        try:
            payload = json.loads(self.path.read_text())
        except (OSError, ValueError) as exc:
            raise DatabaseConfigurationError("database secret is unavailable or invalid") from exc

        missing = [key for key in self.REQUIRED_KEYS if key not in payload]
        if missing:
            raise DatabaseConfigurationError("database secret is missing required fields")
        allowed_modes = ("require", "verify-ca", "verify-full")
        insecure_local = os.getenv("ALLOW_INSECURE_LOCAL_DATABASE", "false").lower() == "true"
        if self.sslmode not in allowed_modes and not (self.sslmode == "disable" and insecure_local):
            raise DatabaseConfigurationError("database TLS mode must verify or require encryption")

        config = {key: payload[key] for key in self.REQUIRED_KEYS}
        config["port"] = int(config["port"])
        config["sslmode"] = self.sslmode
        if self.sslrootcert:
            config["sslrootcert"] = self.sslrootcert
        return config

    @staticmethod
    def fingerprint(config):
        canonical = json.dumps(config, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode()).hexdigest()


def default_pool_factory(config, min_size, max_size, timeout):
    try:
        from psycopg_pool import ConnectionPool
    except ImportError as exc:
        raise DatabaseConfigurationError("PostgreSQL driver is not installed") from exc
    connection_kwargs = dict(config)
    # The mounted secret uses the cloud-neutral field name "username", while
    # libpq/psycopg expects the connection keyword "user".
    connection_kwargs["user"] = connection_kwargs.pop("username")
    connection_kwargs["connect_timeout"] = timeout
    return ConnectionPool(
        kwargs=connection_kwargs,
        min_size=min_size,
        max_size=max_size,
        timeout=timeout,
        open=True,
        name="careflow-api",
    )


class Database:
    """Rotation-aware PostgreSQL access with a bounded connection pool."""

    def __init__(self, config_provider, pool_factory=default_pool_factory,
                 min_size=1, max_size=5, timeout=3):
        self.config_provider = config_provider
        self.pool_factory = pool_factory
        self.min_size = min_size
        self.max_size = max_size
        self.timeout = timeout
        self._lock = threading.RLock()
        self._pool = None
        self._fingerprint = None
        self._migrated_fingerprint = None

    @classmethod
    def from_environment(cls):
        provider = SecretFileConfigProvider(
            os.getenv("DB_SECRET_FILE", "/var/run/secrets/careflow/database.json"),
            sslmode=os.getenv("DB_SSLMODE", "verify-full"),
            sslrootcert=os.getenv("DB_SSLROOTCERT"),
        )
        return cls(
            provider,
            min_size=int(os.getenv("DB_POOL_MIN_SIZE", "1")),
            max_size=int(os.getenv("DB_POOL_MAX_SIZE", "5")),
            timeout=int(os.getenv("DB_CONNECT_TIMEOUT_SECONDS", "3")),
        )

    def _current_pool(self):
        config = self.config_provider.load()
        fingerprint = self.config_provider.fingerprint(config)
        with self._lock:
            if self._pool is not None and fingerprint == self._fingerprint:
                return self._pool, fingerprint

            old_pool = self._pool
            try:
                new_pool = self.pool_factory(
                    config, self.min_size, self.max_size, self.timeout
                )
            except Exception as exc:
                raise DatabaseUnavailable("database connection pool is unavailable") from exc
            self._pool = new_pool
            self._fingerprint = fingerprint
            self._migrated_fingerprint = None
            if old_pool is not None:
                old_pool.close()
            return new_pool, fingerprint

    def _ensure_migrated(self, pool, fingerprint):
        with self._lock:
            if self._migrated_fingerprint == fingerprint:
                return
            migration_dir = pathlib.Path(__file__).resolve().parent / "migrations"
            try:
                with pool.connection(timeout=self.timeout) as connection:
                    connection.execute(
                        "CREATE TABLE IF NOT EXISTS schema_migrations "
                        "(version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"
                    )
                    connection.execute("SELECT pg_advisory_xact_lock(1938475621)")
                    applied = {
                        row[0] for row in connection.execute(
                            "SELECT version FROM schema_migrations"
                        ).fetchall()
                    }
                    for path in sorted(migration_dir.glob("*.sql")):
                        if path.name not in applied:
                            connection.execute(path.read_text())
                            connection.execute(
                                "INSERT INTO schema_migrations(version) VALUES (%s)",
                                (path.name,),
                            )
                    connection.commit()
            except Exception as exc:
                raise DatabaseUnavailable("database migration failed") from exc
            self._migrated_fingerprint = fingerprint

    def check_readiness(self):
        try:
            pool, fingerprint = self._current_pool()
            self._ensure_migrated(pool, fingerprint)
            with pool.connection(timeout=self.timeout) as connection:
                row = connection.execute("SELECT 1").fetchone()
                if not row or row[0] != 1:
                    raise DatabaseUnavailable("database readiness query failed")
        except DatabaseUnavailable:
            raise
        except Exception as exc:
            raise DatabaseUnavailable("database readiness query failed") from exc

    def list_appointments(self):
        try:
            pool, fingerprint = self._current_pool()
            self._ensure_migrated(pool, fingerprint)
            with pool.connection(timeout=self.timeout) as connection:
                rows = connection.execute(
                    "SELECT a.synthetic_id, p.synthetic_id, a.status "
                    "FROM appointments a JOIN patients p ON p.id = a.patient_id "
                    "ORDER BY a.synthetic_id"
                ).fetchall()
            return [
                {"id": row[0], "patient_id": row[1], "status": row[2]}
                for row in rows
            ]
        except DatabaseUnavailable:
            raise
        except Exception as exc:
            raise DatabaseUnavailable("database query failed") from exc

    def close(self):
        with self._lock:
            if self._pool is not None:
                self._pool.close()
                self._pool = None
                self._fingerprint = None
                self._migrated_fingerprint = None
