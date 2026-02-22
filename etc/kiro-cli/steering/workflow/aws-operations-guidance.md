# AWS Operations Guidance

This document defines how Amazon Q should interact with AWS resources, including permission
requirements, allowed operations, and safety guardrails.

## Permission Requirements

### Initial Access Request

Before performing any AWS operations in a chat session, Amazon Q must:

1. **Request explicit permission** from the user with a clear message such as:

   ```text
   I need to access AWS resources to help with your request. This will involve read-only
   operations like describing, listing, or getting information about your AWS resources.

   May I proceed with accessing AWS resources?
   ```

2. **Wait for explicit user confirmation** before making any AWS API calls

3. **Clearly state what type of operations** will be performed (read-only)

### Profile Discovery and Selection

After receiving permission, Amazon Q must:

1. **Discover available AWS profiles** by reading `~/.aws/config`
2. **Present profile options** to the user, showing:
   - Profile names
   - Associated AWS account IDs
   - Default regions
   - SSO configuration details (if applicable)
3. **Prompt for profile selection** with a message such as:

   ```text
   I found the following AWS profiles configured:

   • staging (Account: 438171280653, Region: us-east-1)
   • development (Account: 573151188216, Region: us-east-1)
   • uu-aws-dev (Account: 452418757197, Region: us-east-1)
   • n-aaa (Account: 811402524847, Region: us-east-1)
   • uu-aws-admin (Account: 804656202561, Region: us-east-1)
   • prod (Account: 502667418623, Region: us-west-2)

   Which profile would you like me to use?
   ```

4. **Set the AWS profile** by exporting the `AWS_PROFILE` environment variable:

   ```bash
   export AWS_PROFILE=selected_profile_name
   ```

5. **Confirm the profile selection** before proceeding with AWS operations

### Session Permission Context

- **Permission granted**: Once permission is granted, no additional permission requests are needed
  for subsequent AWS operations within the same chat session
- **Account/Region changes**: If switching between different AWS accounts or regions, request
  permission again as this represents a new security context
- **Session boundaries**: Permission does not carry over between separate chat sessions

## Allowed Operations

Amazon Q is authorized to perform **read-only operations only**, including:

### Permitted AWS CLI Operations

- `describe-*` commands (e.g., `describe-instances`, `describe-vpcs`)
- `list-*` commands (e.g., `list-buckets`, `list-functions`)
- `get-*` commands (e.g., `get-object`, `get-parameter`)
- `show-*` commands where applicable
- Status and health check operations

### Permitted AWS Services

All AWS services are accessible for read-only operations, including but not limited to:

- EC2 (instances, security groups, VPCs)
- S3 (buckets, objects - metadata only)
- Lambda (functions, configurations)
- RDS (instances, clusters)
- IAM (users, roles, policies - for informational purposes)
- CloudFormation (stacks, resources)
- EKS/ECS (clusters, services)
- Systems Manager (parameters, documents)

## Prohibited Operations

### Strictly Forbidden Operations

Amazon Q must **never** perform the following operations, regardless of user permission:

1. **Deletion Operations**

   - Any `delete-*` commands
   - `terminate-*` commands
   - `remove-*` commands
   - Resource destruction of any kind

2. **IAM Modifications**

   - Creating, modifying, or deleting IAM users, roles, or policies
   - Attaching or detaching policies
   - Modifying trust relationships
   - Any IAM write operations

3. **Production Resource Modifications**

   - Creating, modifying, or updating resources
   - Scaling operations (up or down)
   - Configuration changes
   - Network modifications

4. **Billing and Cost Operations**
   - Modifying billing settings
   - Creating or modifying budgets
   - Cost allocation changes

### Write Operations

All write operations are prohibited, including:

- `create-*` commands
- `update-*` commands
- `modify-*` commands
- `put-*` commands (except read-only gets)
- `attach-*` / `detach-*` commands

## Safety Guardrails

### Pre-execution Validation

Before executing any AWS command, Amazon Q should:

1. **Verify the operation is read-only** by checking the command against the allowed operations list
2. **Confirm the AWS profile/region context** if it has changed since the last operation
3. **Validate command syntax** to prevent accidental destructive operations

### Error Handling

- If a prohibited operation is requested, explain why it cannot be performed
- Suggest read-only alternatives when appropriate
- Provide clear error messages without exposing sensitive information

### Command Logging

- Always show the exact AWS CLI command being executed
- Include the AWS profile and region being used
- Provide context about what information the command will retrieve

## Best Practices

### Information Gathering

- Start with broad commands (e.g., `list-instances`) before specific ones
- Use appropriate filters to limit output and improve performance
- Respect AWS API rate limits

### Data Presentation

- Format AWS CLI output for readability
- Highlight important information (e.g., resource states, configurations)
- Summarize large datasets rather than displaying raw JSON when appropriate

### Security Considerations

- Never log or display sensitive information (credentials, secrets)
- Be mindful of data that might be considered sensitive in output
- Use appropriate AWS CLI output formats (table, text) for better security

## Example Permission Flow

```text
User: "Can you show me my EC2 instances?"

Amazon Q: "I need to access AWS resources to help with your request. This will involve
read-only operations like describing, listing, or getting information about your AWS resources.

May I proceed with accessing AWS resources?"

User: "Yes"

Amazon Q: "Thank you. I found the following AWS profiles configured:

• dev (Account: 123456789012, Region: us-east-1)
• staging (Account: 234567890123, Region: us-east-1)
• prod (Account: 345678901234, Region: us-west-2)
• sandbox (Account: 456789012345, Region: us-east-1)

Which profile would you like me to use?"

User: "dev"

Amazon Q: "Setting AWS profile to 'dev' and retrieving your EC2 instances:
export AWS_PROFILE=dev
aws ec2 describe-instances --region us-east-1"

[Executes command and shows results]

User: "What about my S3 buckets?"

Amazon Q: "I'll list your S3 buckets using the same 'dev' profile:
aws s3api list-buckets"

[Executes command without requesting permission again]
```

## Troubleshooting

### Common Issues

- **Permission denied**: Verify AWS credentials and IAM permissions
- **Region not found**: Confirm the correct AWS region is specified
- **Profile not found**: Check AWS CLI profile configuration

### Authentication Issues

If you encounter authentication errors:

1. **Check SSO session status**:

   ```bash
   aws sts get-caller-identity --profile your-profile-name
   ```

2. **If authentication is needed**:

   ```bash
   aws sso login --profile your-profile-name
   ```

3. **Verify the session is active** before Amazon Q attempts AWS operations

### When to Re-request Permission

- User switches AWS profiles explicitly
- User requests operations in a different AWS region
- New chat session begins
- User explicitly asks to change AWS context

This guidance ensures safe, controlled access to AWS resources while maintaining user trust and
preventing accidental destructive operations.
