#!/bin/bash

# ---------------------------------------------------------------
# Persona-to-steering-domain mapping for the Claude Code personas.
#
# Sourced by scripts/generate-personas.sh (installs the personas) and
# scripts/validate-persona-steering.sh (commit-time check), so both read
# one list. Each domain matches the steering the persona's kiro counterpart
# loads via file://~/.kiro/steering/<domain>/**/*.md. Every persona also gets the
# shared/ domain and security/env-file-protection.md, appended by the generator.
# ---------------------------------------------------------------

# shellcheck disable=SC2034 # consumed by the scripts that source this file
PERSONAS=(docs jira datadog ansible)

# Print the steering domain for a persona; return 1 for an unknown persona.
persona_domain() {
    case "$1" in
    docs) echo "documentation" ;;
    jira) echo "scrum" ;;
    datadog) echo "datadog" ;;
    ansible) echo "ansible" ;;
    *) return 1 ;;
    esac
}
