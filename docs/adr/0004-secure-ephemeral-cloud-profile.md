# ADR 0004: Separate secure module defaults from ephemeral demo choices

- Status: Accepted

## Context

Persistent regulated workloads need deletion safeguards, Multi-AZ services and private administration. A portfolio owner also needs an affordable, reversible way to create temporary evidence.

## Decision

Reusable modules default to private EKS access, explicit administrator access, Multi-AZ RDS, deletion protection and final snapshots. The primary environment intentionally selects cheaper database and NAT settings for the `portfolio` profile. If `environment = "production"`, Terraform validation requires per-AZ NAT, Multi-AZ RDS, deletion protection, a final snapshot and an explicit administrator role.

## Alternatives considered

- one production-only default: safe but likely to surprise an inexperienced user with a large bill;
- one cheap default described as production-ready: rejected because it hides real failure domains;
- separate duplicated roots: rejected because configuration drift would obscure the architecture story.

## Trade-offs

Conditional profiles add validation logic and require reviewers to inspect effective variables. The low-cost profile remains unsuitable for production even though the underlying modules support stronger settings.

## Consequences

Documentation and evidence must always name the selected profile. A successful demo does not establish production availability.
