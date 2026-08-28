# Rollback Drill Evidence Template

Status: **PENDING EXECUTION**

- Date/time and timezone:
- Operator:
- Environment (local or cloud sandbox):
- v1 immutable digest or local image ID:
- v2 immutable digest or failure configuration revision:
- Database migration version:
- Start time:
- Failure detected time:
- Recovery complete time:
- Measured recovery duration:

## Redacted command output

Paste the `rollout status`, pod readiness, smoke-test, and recovery output here. Remove account IDs if desired and remove all tokens, passwords, Secret data, connection strings, and personal contact information.

## Observations

- Did ready v1 replicas remain available?
- Did any request fail during the rollout?
- Did the alert fire at the expected time?
- Did Argo CD report the expected health state (cloud variation only)?
- Was recovery performed from Git for the GitOps variation?
- Follow-up actions:
