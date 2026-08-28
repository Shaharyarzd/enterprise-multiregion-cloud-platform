# Interview Story

## 60-second version

“I built and statically validated the foundation of a production-oriented AWS reference platform for a fictional regulated workload: three-AZ networking, EKS, private RDS, hardened Kubernetes, policy definitions, CI security gates and cost controls. I also documented a multi-region target without claiming it already works—the DR code is currently a VPC/EKS scaffold with no regional data path or DNS failover. The next engineering milestone is one evidenced end-to-end delivery path, followed by a measured recovery drill.”

## Deep-dive prompts

### Why warm standby?

Discuss cost, operational complexity, database consistency, recovery objectives and whether active-active is actually justified.

### What happens when an AZ fails?

Discuss replica topology, PDBs, managed node groups, subnets, load balancing and database Multi-AZ behavior.

### What happens when a region fails?

Walk through the DR runbook and distinguish infrastructure recovery from data recovery.

### Where are secrets?

Explain why real secrets are not in Git, why the database can use a service-managed master secret, and why short-lived identity is preferable in CI.

### What would you change for a real healthcare environment?

Do not claim automatic compliance. Discuss governance, auditability, encryption/key ownership, access review, data classification, immutable logs, vulnerability management, incident response, backups and evidence.
