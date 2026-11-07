# Shared Hooks

Lifecycle hook scripts shared by Kiro CLI and Claude Code. Nothing in this directory is installed or
copied: each tool's config calls the scripts in place as `$AI_DOTFILES_DIR/etc/ai/hooks/<script>`.

- **Kiro CLI** wires them in the `hooks` array of each agent JSON in `etc/kiro-cli/cli-agents/`.
- **Claude Code** wires them in the `hooks` block of `etc/claude-code/settings.json`.
- `scripts/validate-hook-wiring.sh` checks hook-wiring drift between the two tools (run by
  pre-commit).

Blocking hooks read the tool-call JSON on stdin and exit `2` with a message on stderr to deny the
call. The other hooks only print to stdout or write a log and never exit `2`, so they never block. A
few can still exit non-zero on an internal error, such as `correction-capture.sh` on malformed
input.

## Wiring a hook

Add the script to `etc/ai/hooks/`, make it executable, then wire it in each tool's config. The
examples wire a blocking `PreToolUse` hook on every tool.

Claude Code, in the `PreToolUse` array under `hooks` in `etc/claude-code/settings.json`:

```json
{
    "matcher": "*",
    "hooks": [
        {
            "type": "command",
            "command": "$AI_DOTFILES_DIR/etc/ai/hooks/block-env-files.sh",
            "timeout": 5,
            "onFailure": "block"
        }
    ]
}
```

Kiro CLI, as an entry in the `hooks` array of each agent JSON in `etc/kiro-cli/cli-agents/`:

```json
{
    "name": "preToolUse-0",
    "trigger": "preToolUse",
    "matcher": "*",
    "action": {
        "type": "command",
        "command": "$AI_DOTFILES_DIR/etc/ai/hooks/block-env-files.sh"
    },
    "timeout": 5
}
```

Kiro agents each carry their own array, so repeat the entry in every agent that should run the hook.
Run `scripts/validate-hook-wiring.sh` afterwards to check that the two tools agree.

## Blocking hooks

| Script                            | What it does                                                                                                                                              | How it is run                                                                           |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `block-env-files.sh`              | Denies any tool input that references a `.env` file.                                                                                                      | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-sops-age-files.sh`         | Denies access to age private keys and `sops` decrypt commands.                                                                                            | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-ssh-private-keys.sh`       | Denies access to `.ssh/id_*` files other than `.pub`.                                                                                                     | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-shell-trace-mode.sh`       | Denies shell trace mode (`set -x`, `set -o xtrace`, `bash -x` and similar).                                                                               | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-memory-secrets.sh`         | Denies engram `mem_save`, `mem_update`, `mem_save_prompt`, `mem_session_summary` and `mem_capture_passive` calls whose strings match credential patterns. | Kiro: `preToolUse`, `@engram/*`, all 5 agents. Claude: `PreToolUse`, `mcp__engram__.*`. |
| `block-persona-shell-commands.sh` | Denies per-persona shell command patterns (`docs`, `jira`, `datadog`, `ansible`), selected by `agent_type` in the payload. Other sessions pass through.   | Claude only: `PreToolUse`, `Bash`.                                                      |

## Warning hooks

| Script                 | What it does                                                                                                                                                                                                                                    | How it is run                                                                                         |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `warn-memory-exfil.sh` | Warns, without blocking, when an engram save contains a download piped into a shell, a reverse-shell construct, a credential-named variable in an outbound request, or an SSH `authorized_keys` or backdoor config directive. Always exits `0`. | Claude only: `PreToolUse`, `mcp__engram__.*`. Emits `hookSpecificOutput.additionalContext` to Claude. |

## Audit and logging hooks

| Script                    | What it does                                                                                                              | How it is run                                                                                        |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `audit-shell-commands.sh` | Appends `aws` and `kubectl` shell commands to `~/.local/share/ai-audit/command-audit.jsonl`, tagged with `AI_AGENT_NAME`. | Kiro: `preToolUse`, `execute_bash`, `code` agent only. Claude: `PostToolUse`, `Bash`, `async: true`. |
| `log-compaction-event.sh` | Records a compaction event in the ai-usage SQLite store; sources `../usage/lib.sh`. See `etc/ai/usage/README.md`.         | Claude only: `PreCompact` and `PostCompact`, `*`.                                                    |

## Session and prompt hooks

| Script                          | What it does                                                                                                                                                                                                                                                     | How it is run                                                                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `recall-memory.sh`              | Prints a recall nudge for the current project's engram memories, or a directive to fetch the active handoff when one exists. Also prints a backlog line when captured corrections are not yet promoted to steering.                                              | Kiro: `agentSpawn`, all 5 agents. Claude: `SessionStart`, `startup\|resume`.                                   |
| `check-engram-hygiene.sh`       | Runs `bin/engram-hygiene check`, which prints a nudge when the current project has pending engram conflict relations.                                                                                                                                            | Kiro: `agentSpawn`, all 5 agents, passing `kiro`. Claude: `SessionStart`, `startup\|resume`, passing `claude`. |
| `suggest-agent-fit.sh`          | Prints a one-time relaunch suggestion when the generalist session starts in a repo with `ansible.cfg` (`ansible`) or `book.toml` (`docs`).                                                                                                                       | Kiro: `agentSpawn`, `code` agent only, passing `code`. Claude: `SessionStart`, `startup`.                      |
| `core-analyses-status.sh`       | On `main` or `master` in a git repo under `~/projects` (override with `CORE_ANALYSIS_PROJECTS_ROOT`), names the core analyses in `analysis/` that are stale or missing, or notes that none exist. Silent when all are current, on other branches, and elsewhere. | Kiro: `agentSpawn`, `code` agent only. Claude: `SessionStart`, `startup\|resume`.                              |
| `correction-capture.sh`         | Nudges the agent to `mem_save` a prompt that looks like a correction, and reminds the user to run `distill-learnings` on the next turn. Keeps a session sentinel under `${TMPDIR:-/tmp}/ai-corrections`.                                                         | Kiro: `userPromptSubmit`, all 5 agents. Claude: `UserPromptSubmit`.                                            |
| `suggest-context-checkpoint.sh` | Prints a compaction warning once per growth phase when the session's input tokens reach `THRESHOLD` (135000 in the script).                                                                                                                                      | Claude only: `UserPromptSubmit`.                                                                               |

## Notes

- `check-engram-hygiene.sh` resolves `bin/engram-hygiene` from `${AI_DOTFILES_DIR:-$HOME/.dotfiles}`
  and exits `0` silently when it is not executable. It requires the agent name as its argument
  (`claude` or `kiro`) and keeps each agent's cadence stamps under `~/.<agent>/engram-hygiene`. A
  missing, extra, or unknown name exits `1` with a message.
- Kiro-only hooks (`check-research-kb.sh`, `clear-research-kb-stale.sh`, `kb-staleness.sh`,
  `rotate-traces.sh`, `trace-tool-call.sh`) live in `etc/kiro-cli/hooks/` and are described in
  `etc/kiro-cli/README.md`.
