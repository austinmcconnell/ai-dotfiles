---
name: aws-operations
description: Guide AWS operations with permission flows and safety guardrails. Use when accessing AWS resources, running AWS CLI commands, describing resources, listing services, or troubleshooting AWS issues.
---

# AWS Operations

Read `references/aws-operations-guidance.md` before performing any AWS operation — it contains the
required permission flow, profile selection steps, allowed/prohibited operations, and safety
guardrails.

## Key Principles

- Always request permission before accessing AWS
- Present profile options and wait for selection
- Only perform read-only operations
- Never delete, modify, or create resources
