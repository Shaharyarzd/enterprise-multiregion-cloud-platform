# Senior Engineer Review Guide

This is the file to hand to an experienced Cloud/DevOps engineer for critique.

Please review the project as if it were proposed for an enterprise production workload. The goal is not approval; the goal is to identify decisions that would need to change in a real environment.

## Architecture review

- Is active-primary / warm-standby justified?
- Are the failure domains realistic?
- Is the RTO/RPO achievable with the proposed data strategy?
- Which components create a hidden regional dependency?

## AWS / cloud review

- Are subnet boundaries sensible?
- Would you expose the EKS API endpoint differently?
- Are IAM and workload identities sufficiently constrained?
- Are there better managed-service choices for this workload?

## Kubernetes review

- Are requests/limits and probes appropriate?
- Is the PDB compatible with maintenance and scaling?
- Are NetworkPolicies sufficient?
- Which admission controls are missing?

## DevOps review

- Is the separation between app delivery and infrastructure changes correct?
- What would you add to progressive delivery?
- What rollback failure modes are missing?

## Security review

- What threat is under-modeled?
- What logs would security/audit teams require?
- What encryption/key-management choices would change for regulated data?

## Cost review

- Which resources dominate cost?
- What would you change for non-production environments?
- Which resilience features are worth their cost?

## Reviewer output

For each issue, record:

- severity: critical / high / medium / low
- current decision
- recommended change
- reasoning
- whether it is portfolio-only or production-critical
