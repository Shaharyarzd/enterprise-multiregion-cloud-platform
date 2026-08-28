# ADR 0001: Use active-primary / warm-standby regional DR

- Status: Accepted for reference architecture

## Context

The fictional workload needs regional recovery but the portfolio must also stay low-cost to demonstrate.

## Decision

Use one active primary regional cell and a separately reproducible warm-standby cell.

Implementation note: the current DR Terraform is only a disabled-by-default VPC/EKS scaffold. It does not satisfy this decision until the application, data, ingress and recovery dependencies are deployed and tested.

## Consequences

### Positive

- materially cheaper than permanently active-active compute/data tiers
- simpler write consistency model
- recovery procedure is explicit and testable

### Negative

- non-zero RTO
- operational procedure is required
- RPO depends on the chosen replication/backup mechanism

## Rejected alternative

Active-active was rejected for milestone 1 because it adds data-consistency, routing, testing and cost complexity without a fictional business requirement that demands near-zero regional RTO.
