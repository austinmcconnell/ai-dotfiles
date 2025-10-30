# AI Prompt Management

This directory contains reusable prompts for AI chat sessions. The prompt management system
provides shell functions to easily save, organize, and reuse common prompts across any AI
service (Amazon Q, Claude, ChatGPT, Gemini, etc.).

## Available Commands

- `ai-save <name>` - Save a new prompt (will prompt for input)
- `ai-use <name>` - Copy prompt to clipboard
- `ai-list` - List all available prompts
- `ai-show <name>` - Display a prompt
- `ai-edit <name>` - Edit a prompt in your default editor
- `ai-delete <name>` - Delete a prompt
- `ai-help` - Show help message

## Usage Examples

### Save a new prompt

```bash
ai-save debugging-python
# Then paste your prompt and press Ctrl+D
```

### Use an existing prompt

```bash
ai-use code-review
# Prompt is copied to clipboard, ready to paste into any AI chat
```

### List available prompts

```bash
ai-list
```

### Edit a prompt

```bash
ai-edit code-review
```

## Organization

Prompts are stored as plain text files in this directory. You can organize them by:

- Creating descriptive names (e.g., `code-review-security`, `documentation-api`)
- Using prefixes for categories (e.g., `debug-`, `review-`, `doc-`)
- Keeping them focused on specific use cases

## AI Service Compatibility

These prompts work with any AI chat service:

- **Amazon Q** - For coding and AWS-related tasks
- **Claude** - For writing, analysis, and general assistance
- **ChatGPT** - For brainstorming and problem-solving
- **Gemini** - For research and creative tasks
- **GitHub Copilot Chat** - For code-specific assistance
- **Any other AI chat service**

## Best Practices

1. **Be specific** - Create prompts for specific scenarios rather than generic ones
2. **Include context** - Add instructions about what type of code or information to include
3. **Use templates** - Include placeholders like `[CODE HERE]` or `[DESCRIPTION]` where appropriate
4. **Version control** - These prompts are tracked in your dotfiles, so you can version and share them
5. **Test prompts** - Try your prompts with different AI services to ensure they produce good results
6. **Cross-platform** - Design prompts that work well across different AI services
7. **Follow dependencies** - Always run prerequisite analyses before dependent ones
   (see Dependency Hierarchy above)
8. **Use main branch** - Most analysis prompts require running from `main` or `master`
   branch for accurate results

## Prompt Dependencies

Many analysis prompts have prerequisite requirements and must be run in a specific order.
Each prompt checks for required analysis files and will abort if prerequisites are missing.

### Dependency Hierarchy

```text
Level 0 (No Dependencies - Can run anytime):
├── project-analysis          # Foundation for all other analyses
├── branch-analysis           # Git branch and commit analysis
├── discover-previous-work    # Understand current implementation state
├── pr-description           # Generate pull request descriptions
├── refactor-plan            # Create refactoring plans
└── vim-practice-session     # Interactive vim skills practice

Level 1 (Requires: project-analysis):
├── architecture-analysis     # System design and architecture
├── schema-analysis          # Database schemas and data models
└── documentation-analysis    # Documentation quality and completeness

Level 2 (Requires: project-analysis + architecture-analysis + schema-analysis):
├── integration-analysis      # External APIs, databases, services
├── testing-analysis         # Testing strategy and coverage
└── technical-debt-analysis  # Code quality and refactoring opportunities

Level 3 (Requires: architecture-analysis + integration-analysis):
└── performance-analysis     # Performance bottlenecks and optimization

Level 4 (Requires: project-analysis + architecture-analysis + integration-analysis):
└── security-analysis        # Security posture and vulnerabilities
```

### Execution Order

For comprehensive project analysis, run prompts in this order:

1. **Start Here**: `project-analysis` (required by most other analyses)
2. **Level 1 Group** (can run in any order):
   - `architecture-analysis` (required by technical analyses)
   - `schema-analysis` (required by integration analysis)
   - `documentation-analysis`
3. **Level 2 Group** (can run in any order):
   - `integration-analysis` (required for performance and security)
   - `testing-analysis`
   - `technical-debt-analysis`
4. **Advanced Analyses**:
   - `performance-analysis` (requires integration-analysis)
   - `security-analysis` (requires project + architecture + integration)

### Independent Prompts

These prompts can be run at any time without prerequisites:

- `branch-analysis` - Analyze current git branch changes
- `discover-previous-work` - Understand work-in-progress state
- `pr-description` - Generate pull request descriptions
- `refactor-plan` - Create refactoring strategies
- `vim-practice-session` - Practice vim skills

## Example Prompts

### Development Analysis

- `project-analysis` - **[FOUNDATION]** Comprehensive project overview and current state
  (outputs to `analysis/project-analysis.md`)
- `architecture-analysis` - Technical architecture and system design analysis (outputs to `analysis/architecture-analysis.md`)
- `schema-analysis` - Database schemas, data models, and API structures (outputs to `analysis/schema-analysis.md`)
- `integration-analysis` - External integrations, APIs, and data flows (outputs to `analysis/integration-analysis.md`)
- `security-analysis` - Security posture, vulnerabilities, and compliance (outputs to `analysis/security-analysis.md`)
- `performance-analysis` - Performance characteristics, bottlenecks, and optimization (outputs to `analysis/performance-analysis.md`)
- `testing-analysis` - Testing strategy, coverage, and quality assurance (outputs to `analysis/testing-analysis.md`)
- `documentation-analysis` - Documentation quality, completeness, and maintenance (outputs to `analysis/documentation-analysis.md`)
- `technical-debt-analysis` - Code quality issues and refactoring opportunities (outputs to `analysis/technical-debt-analysis.md`)

### Git and Code Review

- `branch-analysis` - Analyze git branch differences and changes
- `discover-previous-work` - Analyze previous work and determine next steps
- `pr-description` - Generate pull request descriptions
- `refactor-plan` - Create comprehensive refactoring plans (outputs to markdown file)

### Skills Development

- `vim-practice-session` - Interactive vim skills practice with progress tracking
