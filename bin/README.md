# bin

Commands for the AI tooling. `install.sh` prepends this directory to `PATH` for its own run, and the
dotfiles `.zprofile` adds it to the interactive login `PATH`.

| Command          | Purpose                                                                                    |
| :--------------- | :----------------------------------------------------------------------------------------- |
| `ai-usage`       | Read-only canned reports over the local AI usage and cost SQLite store                     |
| `engram-hygiene` | Report pending engram conflict relations (`status`), or the throttled hook nudge (`check`) |
| `trace-search`   | Search and filter Kiro agent trace logs under `~/.kiro/logs/traces`                        |
| `is-executable`  | Exit 0 when a command exists; used by the install scripts                                  |

For the store behind `ai-usage`, see [etc/ai/usage/README.md](../etc/ai/usage/README.md). The
`engram-hygiene` hook wiring is in [etc/ai/hooks/README.md](../etc/ai/hooks/README.md).
