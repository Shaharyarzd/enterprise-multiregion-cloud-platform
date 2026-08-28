# ADR 0002: GitOps for Kubernetes desired state

- Status: Accepted

## Context

Application delivery needs an auditable desired state without giving every CI job direct cluster credentials.

## Decision

Use Git as the source of desired Kubernetes state and Argo CD as the reconciler.

## Why

- auditable changes
- drift visibility
- declarative rollback path
- clean separation between CI artifact creation and cluster reconciliation

## Trade-off

GitOps introduces another control plane that must itself be secured, monitored and recovered.

## Alternatives considered

- direct `kubectl` from CI: simpler initially, but couples CI credentials to clusters and weakens drift reconciliation;
- Helm invoked by operators: workable for small estates, but provides weaker continuous drift detection;
- managed EKS Argo CD capability: reduces controller operations but adds service cost and platform dependency.

## Consequences

Argo CD bootstrap, repository credentials, project restrictions, notifications and recovery must be owned as platform services. The current repository contains only an Application definition, so the decision is not operationally complete.
