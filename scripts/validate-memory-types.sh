#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-memory-types.sh
#
# Validation-only guard for the engram memory-type vocabulary and the
# handoff convention documented in
# etc/ai/steering/code/cross-session-memory.md.
#
# WHY THIS EXISTS
# engram's `type` field is free text — the store accepts any value and
# enforces nothing at runtime. So the only thing preventing our steering
# from drifting away from engram's vocabulary is a check like this one.
# engram itself ships TWO authoritative type lists that disagree:
#   - README Memory Protocol: bugfix, decision, architecture, discovery,
#     pattern, config, preference
#   - mem_save tool schema (embedded in the binary): decision, architecture,
#     bugfix, pattern, config, discovery, learning (default: manual)
# We reconcile by FUNCTION, not by count:
#   - AGENT-CHOSEN  = types we deliberately pass to mem_save
#   - ENGRAM-GENERATED = learning (passive capture) + manual (default)
#
# WHAT IT CHECKS
#   1. Every AGENT-CHOSEN type below is documented in the steering file.
#   2. Every ENGRAM-GENERATED type below is documented in the steering file.
#   3. The mandatory structured handoff marker line is documented in the steering
#      file (the recall hook confirms handoffs by it; an undocumented or bare-token
#      form is a footgun — the bare token false-matches prose about the convention).
#   4. BEST-EFFORT: if the engram binary is locatable WITHOUT a hardcoded
#      version path, cross-check that its embedded mem_save type list has not
#      diverged from our AGENT-CHOSEN set. If the binary is not found, this
#      check is SKIPPED with a note — never a hard failure. A hardcoded
#      version path (e.g. .../Cellar/engram/1.20.0/...) is deliberately NOT
#      used: it is version- and machine-specific and would silently rot.
#
# The CHECKED-IN sets below are the source of truth. engram divergence is
# surfaced for human review, not auto-adopted.
#
# Exit 0 when the steering file matches the canonical sets; exit 1 on drift.
# ---------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "${DOTFILES_DIR}/install/utils.sh"

STEERING_FILE="${DOTFILES_DIR}/etc/ai/steering/code/cross-session-memory.md"

# Mandatory STRUCTURED marker line the recall hook confirms a handoff by (see
# recall-memory.sh). The bare token alone false-matches any memory that merely
# mentions the convention, so the steering must document the self-referential
# KEY: value form. The <project> placeholder is how it appears in the doc.
HANDOFF_SENTINEL="ENGRAM-HANDOFF-ACTIVE: handoff/<project>-active"

# Canonical AGENT-CHOSEN types — the types we deliberately pass to mem_save.
# Adding a new agent-chosen type means adding ONE line here plus the matching
# bullet in the steering file; the check then enforces the steering got it.
AGENT_CHOSEN_TYPES=(
    decision
    architecture
    bugfix
    pattern
    config
    discovery
    preference
)

# Canonical ENGRAM-GENERATED types — assigned by engram, not hand-picked.
ENGRAM_GENERATED_TYPES=(
    learning
    manual
)

FAILURES=0

RED="\033[0;31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BOLD="\033[1m"
RESET="\033[0m"

report_fail() {
    echo -e "  ${RED}[FAIL]${RESET} $1"
    ((FAILURES++)) || true
}

report_note() {
    echo -e "  ${YELLOW}[NOTE]${RESET} $1"
}

# Assert a literal token appears somewhere in the steering file.
assert_documented() {
    local label="$1" token="$2"
    if ! grep -qF -- "$token" "$STEERING_FILE"; then
        report_fail "${label} not documented in steering: ${token}"
    fi
}

echo -e "${BOLD}Validating engram memory-type vocabulary + handoff convention${RESET}"
echo "──────────────────────────────────────────────────────────────────────────"

if [[ ! -f "$STEERING_FILE" ]]; then
    report_fail "steering file not found: ${STEERING_FILE}"
    echo -e "${RED}✗ cannot validate${RESET}"
    exit 1
fi

# 1 + 2: every canonical type is documented. Match the backtick-quoted form
# (`decision`) so a stray prose mention of the word doesn't satisfy the check.
for t in "${AGENT_CHOSEN_TYPES[@]}"; do
    assert_documented "agent-chosen type" "\`${t}\`"
done
for t in "${ENGRAM_GENERATED_TYPES[@]}"; do
    assert_documented "engram-generated type" "\`${t}\`"
done

# 3: the structured handoff marker line must be documented.
assert_documented "handoff marker" "$HANDOFF_SENTINEL"

# 4: best-effort engram cross-check via DYNAMIC resolution only.
engram_bin=""
if command -v engram >/dev/null 2>&1; then
    engram_bin="$(command -v engram)"
fi

if [[ -z "$engram_bin" ]]; then
    report_note "engram binary not on PATH — skipping engram cross-check (not a failure)"
else
    # The mem_save schema line is embedded in the binary as:
    #   "Category: decision, architecture, bugfix, pattern, config, discovery, learning (default: manual)"
    schema_line="$(strings "$engram_bin" 2>/dev/null |
        grep -iE 'Category:.*decision.*architecture.*bugfix' | head -1 || true)"

    if [[ -z "$schema_line" ]]; then
        report_note "could not locate mem_save schema string in engram binary — skipping cross-check (engram may have changed its help text; review manually)"
    else
        # Any agent-chosen type engram no longer lists in its schema is drift
        # worth a human look. `preference` lives in the README list, not the
        # tool-schema line, so it is expected to be absent here — skip it.
        for t in "${AGENT_CHOSEN_TYPES[@]}"; do
            [[ "$t" == "preference" ]] && continue
            if ! grep -qiE "\\b${t}\\b" <<<"$schema_line"; then
                report_note "engram mem_save schema no longer lists agent-chosen type '${t}' — engram's vocabulary may have shifted; review whether the steering set should change"
            fi
        done
    fi
fi

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} memory-type / handoff drift issue(s) found${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ Steering memory-type vocabulary and handoff convention are consistent${RESET}"
