# Requirements & Assumptions

## Fictional business context

CareFlow is a synthetic healthcare SaaS service. The architecture assumes a regulated environment without claiming compliance certification.

## Functional requirements

- Expose a stateless HTTPS API.
- Support horizontal scaling.
- Support independent application and infrastructure releases.
- Provide a regional recovery capability.
- Persist only synthetic patient identifiers and appointment status in PostgreSQL.

## Non-functional requirements

| Category | Requirement |
|---|---|
| Availability | Survive a single AZ failure without manual application redeployment |
| Scalability | Scale stateless API replicas horizontally |
| Recovery | Target RTO <= 60 minutes and RPO <= 15 minutes |
| Security | Encrypt data in transit/at rest; least privilege; non-root workloads |
| Observability | Collect health, latency, error and saturation signals |
| Operability | Infrastructure and workload state reproducible from Git |
| Cost | Normal development must not require a running cloud environment |

## Explicit non-goals through milestone 2

- Formal HIPAA/HITRUST certification.
- Real PHI/PII storage.
- Multi-master database writes.
- A 24x7 production SLA.
- Fully automated failover without operator validation.
- A real patient/healthcare dataset.
- An always-on public cloud demo.
- WAF without a justified threat and cost case.

## Constraints

- Public portfolio: no confidential employer information.
- Low-cost build: cloud resources remain optional and ephemeral.
- Reviewable by recruiters: major design choices must be documented, not hidden in code.
