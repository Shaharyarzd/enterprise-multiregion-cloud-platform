.PHONY: verify test preflight local-demo local-up local-down smoke-test rollout-demo check-shell

verify:
	python3 scripts/verify.py
	python3 scripts/check-public-repo-identifiers.py

test:
	python3 -m unittest discover -s apps/careflow-api/tests -p 'test_*.py'

preflight:
	bash scripts/preflight.sh all

local-demo:
	bash scripts/local-demo.sh

local-up:
	bash scripts/bootstrap-local.sh

local-down:
	kind delete cluster --name careflow-portfolio || true

smoke-test:
	bash scripts/smoke-test.sh

rollout-demo:
	bash scripts/rollout-failure-demo.sh

check-shell:
	find scripts platform -type f -name '*.sh' -exec bash -n {} +
