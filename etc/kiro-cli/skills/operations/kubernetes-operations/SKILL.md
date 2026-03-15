---
name: kubernetes-operations
description: >-
  Guide Kubernetes operations with permission flows and safety guardrails. Use when
  accessing Kubernetes clusters, running kubectl commands, listing pods, describing
  resources, or troubleshooting K8s issues.
---

# Kubernetes Operations

Follow the complete operational guidance in `references/kubernetes-operations-guidance.md`.

## Key Principles

- Always request permission before accessing clusters
- Present context options and wait for selection
- Only perform read-only operations
- Never delete, modify, or execute into pods

See the reference file for complete permission flows, allowed operations, and safety guardrails.
