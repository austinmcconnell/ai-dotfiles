# Shared Hooks

Lifecycle hook scripts shared by Kiro CLI and Claude Code. Nothing in this directory is installed or
copied: each tool's config calls the scripts in place as `$AI_DOTFILES_DIR/etc/ai/hooks/<script>`.

- **Kiro CLI** wires them in the `hooks` array of each agent JSON in `etc/kiro-cli/cli-agents/`.
- **Claude Code** wires them in the `hooks` block of `etc/claude-code/settings.json`.
- `scripts/validate-hook-wiring.sh` checks hook-wiring drift between the two tools (run by
  pre-commit).

Blocking hooks read the tool-call JSON on stdin and exit `2` with a message on stderr to deny the
call. The other hooks only print to stdout or write a log and always exit `0`.

## Blocking hooks

| Script                            | What it does                                                                                                                                              | How it is run                                                                           |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `block-env-files.sh`              | Denies any tool input that references a `.env` file.                                                                                                      | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-sops-age-files.sh`         | Denies access to age private keys and `sops` decrypt commands.                                                                                            | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-ssh-private-keys.sh`       | Denies access to `.ssh/id_*` files other than `.pub`.                                                                                                     | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-shell-trace-mode.sh`       | Denies shell trace mode (`set -x`, `set -o xtrace`, `bash -x` and similar).                                                                               | Kiro: `preToolUse`, `*`, all 5 agents. Claude: `PreToolUse`, `*`.                       |
| `block-memory-secrets.sh`         | Denies engram `mem_save`, `mem_update`, `mem_save_prompt`, `mem_session_summary` and `mem_capture_passive` calls whose strings match credential patterns. | Kiro: `preToolUse`, `@engram/*`, all 5 agents. Claude: `PreToolUse`, `mcp__engram__.*`. |
| `block-persona-shell-commands.sh` | Denies per-persona shell command patterns (`docs`, `jira`, `datadog`, `ansible`), selected by `agent_type` in the payload. Other sessions pass through.   | Claude only: `PreToolUse`, `Bash`.                                                      |

## Audit and logging hooks

| Script                    | What it does                                                                                                              | How it is run                                                                                        |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `audit-shell-commands.sh` | Appends `aws` and `kubectl` shell commands to `~/.local/share/ai-audit/command-audit.jsonl`, tagged with `AI_AGENT_NAME`. | Kiro: `preToolUse`, `execute_bash`, `code` agent only. Claude: `PostToolUse`, `Bash`, `async: true`. |
| `log-compaction-event.sh` | Records a compaction event in the ai-usage SQLite store; sources `../usage/lib.sh`. See `etc/ai/usage/README.md`.         | Claude only: `PreCompact` and `PostCompact`, `*`.                                                    |

## Session and prompt hooks

| Script                          | What it does                                                                                                                                                                                             | How it is run                                                                                                  |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `recall-memory.sh`              | Prints a recall nudge for the current project's engram memories, or a directive to fetch the active handoff when one exists.                                                                             | Kiro: `agentSpawn`, all 5 agents. Claude: `SessionStart`, `startup\|resume`, with `AI_AGENT_NAME=claude-code`. |
| `check-engram-hygiene.sh`       | Runs `bin/engram-hygiene check`, which prints a nudge when the current project has pending engram conflict relations.                                                                                    | Kiro: `agentSpawn`, all 5 agents. Claude: `SessionStart`, `startup\|resume`.                                   |
| `suggest-agent-fit.sh`          | Prints a one-time relaunch suggestion when the generalist session starts in a repo with `ansible.cfg` (`ansible`) or `book.toml` (`docs`).                                                               | Kiro: `agentSpawn`, `code` agent only, passing `code`. Claude: `SessionStart`, `startup`.                      |
| `correction-capture.sh`         | Nudges the agent to `mem_save` a prompt that looks like a correction, and reminds the user to run `distill-learnings` on the next turn. Keeps a session sentinel under `${TMPDIR:-/tmp}/ai-corrections`. | Kiro: `userPromptSubmit`, all 5 agents. Claude: `UserPromptSubmit`.                                            |
| `suggest-context-checkpoint.sh` | Prints a compaction warning once per growth phase when the session's input tokens reach `THRESHOLD` (135000 in the script).                                                                              | Claude only: `UserPromptSubmit`.                                                                               |

## Notes

- `check-engram-hygiene.sh` resolves `bin/engram-hygiene` from `${AI_DOTFILES_DIR:-$HOME/.dotfiles}`
  and exits `0` silently when it is not executable.
- The header comment of `recall-memory.sh` says it relies on `timeout_ms (5000ms)`; the agent JSON
  and `settings.json` set `timeout` (seconds, `5`) instead.
- Kiro-only hooks (`check-research-kb.sh`, `clear-research-kb-stale.sh`, `kb-staleness.sh`,
  `rotate-traces.sh`, `trace-tool-call.sh`) live in `etc/kiro-cli/hooks/` and are described in
  `etc/kiro-cli/README.md`.
