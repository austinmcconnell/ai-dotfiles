---
name: kubernetes-operations
description: Guide Kubernetes operations with permission flows and safety guardrails. Use when accessing Kubernetes clusters, running kubectl commands, listing pods, describing resources, or troubleshooting K8s issues.
---

# Kubernetes Operations

Read `references/kubernetes-operations-guidance.md` before performing any cluster operation — it
contains the required permission flow, context selection steps, allowed/prohibited operations, and
safety guardrails.

## Key Principles

- Always request permission before accessing clusters
- Present context options and wait for selection
- Only perform read-only operations
- Never delete, modify, or execute into pods
