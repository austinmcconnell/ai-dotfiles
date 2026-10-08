# Vim Native-Coverage Audit

Audit the Vim plugin list for **drop candidates** — plugins whose behavior stock Vim now implements
natively, or that the config does not actually exercise. The goal is a per-plugin verdict table you
can act on, not a generic "review the config" pass.

This audit is deliberately narrow: it asks only "does stock Vim already cover this?" It is not a
full plugin-quality review. Scope creep back into "audit everything" is the failure mode this prompt
exists to prevent.

## Local Configuration Discovery

Read these to understand the current setup before auditing:

- `etc/vim/.vimrc` — the `Plug` declaration list (the audit's input) plus general settings
- `etc/vim/plugin/` — per-plugin wiring; **each plugin's real config lives here**, one file per
  plugin. Read the config for every plugin you deep-audit — the cost of dropping depends on what the
  config actually uses, not on the plugin's full feature set.
- `etc/vim/after/ftplugin/` — per-language overrides that may already replace or depend on a plugin
- `etc/vim/README.md` and the `AGENTS.md` "Vim Configuration Architecture" section — conventions

Note any `plugin/<name>.vim` config file with **no matching `Plug` line** in `.vimrc` — these are
orphans from previously-removed plugins. Report them separately; they are cleanup, not drop
candidates.

## Pin the Stock Baseline First

Native coverage is **version-specific** — a plugin that stock Vim cannot replace today may be
covered two releases from now, and vice versa. Before auditing anything:

1. Run `vim --version | head -3` and record the exact version + patch level in the output. Every
   verdict is only valid for that version.
1. List the native optional packages this build ships:
   `ls "$(vim -u NONE -N -es -c 'echo $VIMRUNTIME' -c 'qa!' 2>&1 | tr -d "\n")/pack/dist/opt/"`
   (or inspect `pack/dist/opt/` under the Vim runtime directly). These are candidates for replacing
   plugins — but see the `packadd` note below.

## Triage Before Deep-Auditing

Do not deep-audit every plugin. First split the `Plug` list:

- **Presumptive keeps** (stock Vim has no equivalent) — fuzzy finder, git-gutter/sign-column git,
  statusline framework, linter/LSP, file-tree explorer, tag management, session management,
  colorschemes, prose/writing tools. Set these aside with a one-line "no stock equivalent" reason.
- **Plausible candidates** (deep-audit these) — commenting, auto-pairs, surround, endwise/auto-end,
  and anything touching **syntax / ftdetect / indent / folding** (these are where a vendored copy
  most often shadows newer stock runtime files).

Spend the audit budget on the plausible set. The presumptive-keep list only needs its one-liner.

## Per-Plugin Audit — Verify, Never Recall

For each deep-audited plugin, determine four things. **Verify stock coverage with probes, never from
training-data memory** — the single most important discipline here. Memory about "what stock Vim
covers" is routinely wrong; only the probes below are evidence.

1. **(a) What it provides** — the specific behavior, drawn from its actual `plugin/` config, not its
   full upstream feature set.

1. **(b) Does stock Vim cover it?** Prove it with:

   - **True stock baseline:** `vim -u NONE -N` + `filetype plugin indent on` — a Vim with no
     plugins on the runtimepath. Test the behavior there. Never test against the fully-configured
     Vim; the plugin you are auditing is loaded and will mask the answer.
   - **Shadowing check:** `globpath(&rtp, 'syntax/<x>.vim')` (and `indent/`, `ftplugin/`,
     `after/`) to see whether a vendored file sits ahead of `$VIMRUNTIME` on the runtimepath and
     wins first-match. A plugin under `pack/*/start/` loads ahead of the stock runtime, so its
     vendored copy can silently shadow a newer stock file.
   - **`start` vs `opt`:** a native feature shipped as an **optional** package
     (`pack/dist/opt/<name>/`) is **inert until `packadd <name>`** — nothing auto-loads it. If the
     replacement is an opt package, the drop requires adding `packadd <name>`, not just deleting the
     `Plug` line. Confirm the package exists and that `packadd <name>` makes the expected mappings/
     commands resolve (`maparg(...)`, `exists(':Cmd')`).
   - **End-state check:** before declaring a drop safe, confirm the behavior with the plugin absent
     from the runtimepath — either strip it (`set rtp-=.../<plugin>`) or test under `-u NONE` + the
     proposed replacement sourced. Confirm stock (or the opt package) actually wins.

   **The common false drop:** a superficially-similar native feature that is not a real replacement.
   `matchparen` only *highlights* a matching pair — it does not auto-insert one (not an auto-pairs
   replacement). `matchit` extends `%` jumping — it does not add/change/delete surroundings (not a
   surround replacement). When claiming stock coverage, name the *specific behavior* and confirm the
   native feature does that exact thing, not merely something adjacent.

1. **(c) Does this config actually use the feature?** Grep the config tree for the plugin's
   commands, mappings, and settings. A plugin whose feature is never invoked is a drop candidate on
   usage grounds alone, independent of stock coverage.

1. **(d) Cost of dropping** — broken out by axis so the verdict is legible:

   - **Detection** — filetype/ftdetect rules that would be lost
   - **Syntax** — highlighting that stock does/doesn't match
   - **Indent / folding behavior** — indentexpr/foldexpr differences (stock often has no folding
     where a plugin added a tuned foldexpr; the fallback is coarser)
   - **Commands / mappings** — what the user types that would stop working, and whether the
     replacement provides the same keys

## Output Format

Write findings to `analysis/vim-native-coverage-audit.md` with:

1. **Baseline** — the exact `vim --version` + patch level audited, and the list of native opt
   packages this build ships. State plainly that verdicts are valid only for this version.
1. **Presumptive keeps** — the triaged no-stock-equivalent list, one line each.
1. **Verdict table** — one row per deep-audited plugin with columns: Plugin · (a) provides · (b)
   stock covers? (with the probe result) · (c) config uses it? · (d) drop cost by
   detection/syntax/indent/commands-mappings · **Verdict**.
1. **Verdicts** are one of:
   - **Clear-drop** — stock fully covers it, verified; name the replacement and any required
     `packadd`.
   - **Keep** — no stock equivalent, or actively depended on.
   - **Needs-discussion** — stock partially covers it; dropping is a real but minor regression (name
     it) for the user to weigh.
1. **Orphan configs** — `plugin/*.vim` files with no matching `Plug` line (cleanup candidates).

## Acting on a Clear-Drop (repo conventions)

If the user chooses to act on a clear-drop, follow these repo-specific conventions:

- **Per-plugin wiring stays in `plugin/`.** The native replacement's activation (`packadd <name>`)
  and any convenience mappings belong in `etc/vim/plugin/<name>.vim`, **not** inlined in `.vimrc`.
  `.vimrc` only loses its `Plug` line. When a plugin is replaced by native functionality, repurpose
  (and rename) its existing `plugin/` config file to host the native activation rather than deleting
  it outright — the keymaps it carries are the activation seam.
- **`:PlugClean` is a required manual follow-up.** Removing a `Plug` line does **not** unload the
  already-vendored copy under `pack/*/start/` in a running Vim; the user must run `:PlugClean` to
  physically prune it. Always call this out as a post-step — a drop looks like a no-op until it runs.

Do not edit `.vimrc` or any config as part of the audit. The audit produces a verdict table for the
user to review; acting on it is a separate, user-approved step.
