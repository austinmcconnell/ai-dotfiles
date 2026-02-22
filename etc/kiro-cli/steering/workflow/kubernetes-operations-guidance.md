# Kubernetes Operations Guidance

This document defines how Amazon Q should interact with Kubernetes clusters and resources, including
permission requirements, allowed operations, and safety guardrails.

## Permission Requirements

### Initial Access Request

Before performing any Kubernetes operations in a chat session, Amazon Q must:

1. **Request explicit permission** from the user with a clear message such as:

   ```text
   I need to access Kubernetes resources to help with your request. This will involve read-only
   operations like getting, describing, or listing information about your Kubernetes resources.

   May I proceed with accessing Kubernetes resources?
   ```

2. **Wait for explicit user confirmation** before making any kubectl commands

3. **Clearly state what type of operations** will be performed (read-only)

### Context Discovery and Selection

After receiving permission, Amazon Q must:

1. **Discover available Kubernetes contexts** by reading `~/.kube/config`
2. **Present context options** to the user, showing:
   - Context names
   - Associated cluster information
   - Default namespaces
   - Cluster types (EKS, local, etc.)
3. **Prompt for context selection** with a message such as:

   ```text
   I found the following Kubernetes contexts configured:

   • development (EKS: dev-cluster, Namespace: default)
   • staging (EKS: staging-cluster, Namespace: app-staging)
   • production (EKS: prod-cluster, Namespace: production)
   • docker-desktop (Local cluster, Namespace: default)
   • testing (EKS: test-cluster, Namespace: testing)

   Which context would you like me to use?
   ```

4. **Set the Kubernetes context** using:

   ```bash
   kubectl config use-context selected_context_name
   ```

5. **Confirm the context selection** before proceeding with Kubernetes operations

### Session Permission Context

- **Permission granted**: Once permission is granted, no additional permission requests are needed
  for subsequent Kubernetes operations within the same chat session
- **Context changes**: If switching between different Kubernetes contexts, request permission again
  as this represents a new cluster/security context
- **Session boundaries**: Permission does not carry over between separate chat sessions

## Allowed Operations

Amazon Q is authorized to perform **read-only operations only**, including:

### Permitted kubectl Operations

- `get` commands (e.g., `kubectl get pods`, `kubectl get services`)
- `describe` commands (e.g., `kubectl describe deployment`, `kubectl describe node`)
- `logs` commands (e.g., `kubectl logs pod-name`)
- `top` commands (e.g., `kubectl top nodes`, `kubectl top pods`)
- `explain` commands (e.g., `kubectl explain deployment`)
- `config` view commands (e.g., `kubectl config view`, `kubectl config get-contexts`)

### Permitted Resource Types

All Kubernetes resource types are accessible for read-only operations, including:

- Pods, Deployments, Services, ConfigMaps, Secrets (metadata only)
- Nodes, Namespaces, PersistentVolumes, PersistentVolumeClaims
- Ingresses, NetworkPolicies, ServiceAccounts
- Custom Resources and CRDs
- Cluster-level resources (when permissions allow)

## Prohibited Operations

### Strictly Forbidden Operations

Amazon Q must **never** perform the following operations, regardless of user permission:

1. **Deletion Operations**

   - Any `delete` commands
   - `kubectl delete` of any resource type
   - Resource destruction of any kind

2. **Modification Operations**

   - `apply`, `create`, `replace` commands
   - `patch`, `edit` commands
   - `scale` operations
   - `rollout` operations (restart, undo, etc.)

3. **Cluster Administration**

   - `drain`, `cordon`, `uncordon` node operations
   - `label`, `annotate` operations
   - Certificate or RBAC modifications

4. **Execution Operations**
   - `exec` into pods
   - `port-forward` operations
   - `proxy` operations
   - `cp` (copy files to/from pods)

### Write Operations

All write operations are prohibited, including:

- Creating or modifying any Kubernetes resources
- Executing commands inside containers
- Modifying cluster configuration
- Changing resource labels or annotations

## Safety Guardrails

### Pre-execution Validation

Before executing any kubectl command, Amazon Q should:

1. **Verify the operation is read-only** by checking the command against the allowed operations list
2. **Confirm the Kubernetes context** if it has changed since the last operation
3. **Validate command syntax** to prevent accidental destructive operations
4. **Check for production context warnings** when accessing production clusters

### Error Handling

- If a prohibited operation is requested, explain why it cannot be performed
- Suggest read-only alternatives when appropriate
- Provide clear error messages without exposing sensitive information
- Handle authentication errors gracefully

### Command Logging

- Always show the exact kubectl command being executed
- Include the Kubernetes context and namespace being used
- Provide context about what information the command will retrieve

## Best Practices

### Information Gathering

- Start with broad commands (e.g., `kubectl get pods`) before specific ones
- Use appropriate namespaces and selectors to limit output
- Respect cluster resources and avoid excessive API calls

### Data Presentation

- Format kubectl output for readability
- Highlight important information (e.g., pod status, resource usage)
- Summarize large datasets rather than displaying raw YAML when appropriate

### Security Considerations

- Never log or display sensitive information (secrets, tokens)
- Be mindful of data that might be considered sensitive in output
- Use appropriate kubectl output formats (table, wide) for better security
- Warn users when accessing production clusters

## Example Permission Flow

```text
User: "Can you show me the pods in my cluster?"

Amazon Q: "I need to access Kubernetes resources to help with your request. This will involve
read-only operations like getting, describing, or listing information about your Kubernetes resources.

May I proceed with accessing Kubernetes resources?"

User: "Yes"

Amazon Q: "Thank you. I found the following Kubernetes contexts configured:

• development (EKS: dev-cluster, Namespace: default)
• staging (EKS: staging-cluster, Namespace: app-staging)
• production (EKS: prod-cluster, Namespace: production)
• docker-desktop (Local cluster, Namespace: default)

Which context would you like me to use?"

User: "development"

Amazon Q: "Setting Kubernetes context to 'development' and retrieving pods:
kubectl config use-context development
kubectl get pods -n default"

[Executes command and shows results]

User: "What about the services?"

Amazon Q: "I'll list the services in the same context:
kubectl get services -n default"

[Executes command without requesting permission again]
```

## Troubleshooting

### Common Issues

- **Permission denied**: Verify kubectl configuration and cluster permissions
- **Context not found**: Check available contexts with `kubectl config get-contexts`
- **Connection refused**: Verify cluster connectivity and authentication

### Authentication Issues

If you encounter authentication errors:

1. **Check current context**:

   ```bash
   kubectl config current-context
   ```

2. **Verify cluster connection**:

   ```bash
   kubectl cluster-info
   ```

3. **For EKS clusters, ensure AWS authentication**:

   ```bash
   aws sts get-caller-identity --profile your-profile-name
   ```

4. **Update kubeconfig if needed**:

   ```bash
   aws eks update-kubeconfig --region us-east-1 --name cluster-name --profile your-profile-name
   ```

### When to Re-request Permission

- User switches Kubernetes contexts explicitly
- User requests operations in a different cluster
- New chat session begins
- User explicitly asks to change cluster context

## Production Cluster Warnings

When accessing production clusters, Amazon Q should:

- Display a clear warning about the production environment
- Emphasize read-only nature of operations
- Be extra cautious with command validation
- Suggest using non-production environments for testing

This guidance ensures safe, controlled access to Kubernetes resources while maintaining user trust
and preventing accidental destructive operations across multiple cluster environments.
