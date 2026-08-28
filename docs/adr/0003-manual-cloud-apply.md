# ADR 0003: Do not auto-apply cloud infrastructure from CI

- Status: Accepted for portfolio

## Decision

CI may validate and plan infrastructure, but apply remains an explicit operator action.

## Rationale

The repository is public and designed to be forked. Automatic applies create unnecessary cost and safety risk. In a real enterprise, this could evolve to an approved deployment workflow with environment protection, policy gates, short-lived cloud identity and change-management controls.

## Alternatives considered

- automatic apply on merge: rejected for a forkable portfolio because billing/account ownership cannot be assumed;
- local-only Terraform: rejected because it produces weak review and audit evidence;
- manually dispatched apply workflow: deferred until OIDC, protected environments, concurrency locking and a sandbox account are in scope.

## Consequences

The repository proves static validity, not successful cloud deployment. Operators must capture an authenticated plan/apply, post-deploy checks and teardown evidence separately. Manual operation is not an exemption from peer review or least privilege.
