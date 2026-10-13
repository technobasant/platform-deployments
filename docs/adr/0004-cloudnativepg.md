# 4. CloudNativePG for PostgreSQL in the cluster, RDS on AWS

Status: accepted · 2026-10

## Context

governed-agent needs PostgreSQL. In a kind cluster the options are a Helm chart that
runs PostgreSQL as a StatefulSet (Bitnami's, historically), an operator, or a
database outside the cluster.

## Decision

* CloudNativePG: an operator that manages a two-instance cluster (`ga-pg`), with
  streaming replication, automated failover and a PodMonitor for its exporter.
* The application reads the generated `ga-pg-app` secret and connects to `ga-pg-rw`,
  the service that always points at the primary.
* On AWS (`terraform/aws`) the database is RDS PostgreSQL instead; the chart only
  needs a host, a database name and a secret.

## Why not the alternatives

* A StatefulSet chart gives you pods with PostgreSQL in them; failover, replica
  rebuilds and switchover are left to you. Bitnami's catalogue has also moved most
  images behind a subscription, which makes it a poor base for a public repository.
* A managed database is the right production answer, and the Terraform says so. It
  cannot run inside kind.

## Consequences

* The node drain test meets a real constraint: an instance on node-local storage
  cannot move to another node, and draining the primary's node needs a switchover
  first. MEASUREMENTS.md drains the other worker and says so.
* CloudNativePG's own PodDisruptionBudgets apply during drains.
