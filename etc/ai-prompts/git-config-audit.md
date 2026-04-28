# Git Config Audit

Read all files in etc/git/ (config, config-uniteus, config-macos,
config-linux, attributes, ignore, commit-template, hooks/\*, and
README.md). Determine my git version by running `git --version`.

For each file, identify git features or config options introduced
since the last audit (April 2026, git 2.54) that could improve,
simplify, or replace what I currently have.

Focus on:

1. New options that replace workarounds or verbose patterns in my
   current config
1. Features I'm not using that would benefit my workflow
   (rebase-heavy, linear history, multi-repo, remote work across
   2 machines)
1. Deprecated or superseded options I should update
1. New defaults that make existing config lines redundant
1. New hook types or hook features that could improve my hooks
1. New attributes or ignore patterns worth adopting

Skip cosmetic changes. For each recommendation, cite the git
version that introduced it. Prioritize things where a newer
feature is strictly better regardless of other choices.
