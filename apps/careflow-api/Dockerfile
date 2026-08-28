FROM python:3.13-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends ca-certificates curl && \
    curl --fail --silent --show-error --location \
      https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
      --output /etc/ssl/certs/aws-rds-global-bundle.pem && \
    echo 'e5bb2084ccf45087bda1c9bffdea0eb15ee67f0b91646106e466714f9de3c7e3  /etc/ssl/certs/aws-rds-global-bundle.pem' | sha256sum --check && \
    apt-get purge --yes --auto-remove curl && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --system --gid 10001 app && \
    useradd --system --uid 10001 --gid 10001 --home-dir /nonexistent app

COPY requirements.txt .
RUN python -m pip install --no-cache-dir --requirement requirements.txt && \
    python -m pip uninstall --yes setuptools wheel pip

COPY app.py persistence.py ./
COPY migrations ./migrations

USER 10001:10001

FROM base AS test
COPY --chown=10001:10001 tests ./tests
CMD ["python", "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"]

FROM base AS runtime
EXPOSE 8080

CMD ["python", "app.py"]
