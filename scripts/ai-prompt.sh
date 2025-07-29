#!/usr/bin/env bash

# AI prompt management with subcommands and tab completion

# Main ai-prompt function
ai-prompt() {
    local cmd="$1"
    shift

    case "$cmd" in
    save | s)
        _ai_prompt_save "$@"
        ;;
    list | ls | l)
        _ai_prompt_list "$@"
        ;;
    use | u)
        _ai_prompt_use "$@"
        ;;
    show | cat)
        _ai_prompt_show "$@"
        ;;
    edit | e)
        _ai_prompt_edit "$@"
        ;;
    delete | rm | d)
        _ai_prompt_delete "$@"
        ;;
    help | h | --help | -h)
        _ai_prompt_help
        ;;
    "")
        _ai_prompt_help
        ;;
    *)
        echo "Unknown command: $cmd"
        echo "Run 'ai-prompt help' for usage information"
        return 1
        ;;
    esac
}

# Get prompt directory
_ai_prompt_dir() {
    echo "$HOME/.dotfiles/etc/ai-prompts"
}

# Get list of available prompts (without .txt extension)
_ai_prompt_names() {
    local prompt_dir
    prompt_dir="$(_ai_prompt_dir)"

    if [[ -d "$prompt_dir" ]]; then
        find "$prompt_dir" -name "*.txt" -type f 2>/dev/null | sed 's|.*/||; s|\.txt$||' | sort
    fi
}

# Save a prompt
_ai_prompt_save() {
    local name="$1"
    local prompt_dir
    prompt_dir="$(_ai_prompt_dir)"

    if [[ -z "$name" ]]; then
        echo "Usage: ai-prompt save <prompt-name>"
        echo "Then paste your prompt and press Ctrl+D"
        return 1
    fi

    mkdir -p "$prompt_dir"
    echo "Enter your prompt (press Ctrl+D when done):"
    cat >"$prompt_dir/$name.txt"
    echo "Prompt saved as '$name'"
}

# List available prompts
_ai_prompt_list() {
    local prompt_dir
    prompt_dir="$(_ai_prompt_dir)"

    if [[ ! -d "$prompt_dir" ]]; then
        echo "No prompts directory found. Use 'ai-prompt save' to create your first prompt."
        return 1
    fi

    local prompts
    prompts="$(_ai_prompt_names)"

    if [[ -z "$prompts" ]]; then
        echo "No prompts found. Use 'ai-prompt save <name>' to create your first prompt."
        return 1
    fi

    echo "Available prompts:"
    # shellcheck disable=SC2001
    echo "$prompts" | sed 's/^/  /'
}

# Use a prompt (copy to clipboard)
_ai_prompt_use() {
    local name="$1"
    local prompt_dir
    prompt_dir="$(_ai_prompt_dir)"
    local prompt_file="$prompt_dir/$name.txt"

    if [[ -z "$name" ]]; then
        echo "Usage: ai-prompt use <prompt-name>"
        echo "Available prompts:"
        _ai_prompt_list
        return 1
    fi

    if [[ ! -f "$prompt_file" ]]; then
        echo "Prompt '$name' not found."
        echo "Available prompts:"
        _ai_prompt_list
        return 1
    fi

    # Copy to clipboard (macOS)
    if command -v pbcopy >/dev/null 2>&1; then
        pbcopy <"$prompt_file"
        echo "Prompt '$name' copied to clipboard"
    # Copy to clipboard (Linux with xclip)
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard <"$prompt_file"
        echo "Prompt '$name' copied to clipboard"
    else
        echo "Clipboard tool not found. Here's your prompt:"
        echo "----------------------------------------"
        cat "$prompt_file"
        echo "----------------------------------------"
    fi
}

# Edit a prompt
_ai_prompt_edit() {
    local name="$1"
    local prompt_dir
    prompt_dir="$(_ai_prompt_dir)"
    local prompt_file="$prompt_dir/$name.txt"

    if [[ -z "$name" ]]; then
        echo "Usage: ai-prompt edit <prompt-name>"
        echo "Available prompts:"
        _ai_prompt_list
        return 1
    fi

    mkdir -p "$prompt_dir"
    ${EDITOR:-vim} "$prompt_file"
}

# Show a prompt
_ai_prompt_show() {
    local name="$1"
    local prompt_dir
    prompt_dir="$(_ai_prompt_dir)"
    local prompt_file="$prompt_dir/$name.txt"

    if [[ -z "$name" ]]; then
        echo "Usage: ai-prompt show <prompt-name>"
        echo "Available prompts:"
        _ai_prompt_list
        return 1
    fi

    if [[ ! -f "$prompt_file" ]]; then
        echo "Prompt '$name' not found."
        return 1
    fi

    echo "=== Prompt: $name ==="
    cat "$prompt_file"
}

# Delete a prompt
_ai_prompt_delete() {
    local name="$1"
    local prompt_dir
    prompt_dir="$(_ai_prompt_dir)"
    local prompt_file="$prompt_dir/$name.txt"

    if [[ -z "$name" ]]; then
        echo "Usage: ai-prompt delete <prompt-name>"
        echo "Available prompts:"
        _ai_prompt_list
        return 1
    fi

    if [[ ! -f "$prompt_file" ]]; then
        echo "Prompt '$name' not found."
        return 1
    fi

    echo "Are you sure you want to delete prompt '$name'? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm "$prompt_file"
        echo "Prompt '$name' deleted"
    else
        echo "Deletion cancelled"
    fi
}

# Help function
_ai_prompt_help() {
    echo "AI Prompt Management"
    echo ""
    echo "Usage: ai-prompt <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  save <name>     Save a new prompt (will prompt for input)"
    echo "  use <name>      Copy prompt to clipboard"
    echo "  list            List all available prompts"
    echo "  show <name>     Display a prompt"
    echo "  edit <name>     Edit a prompt in your default editor"
    echo "  delete <name>   Delete a prompt"
    echo "  help            Show this help message"
    echo ""
    echo "Aliases:"
    echo "  s, save         l, ls, list         u, use"
    echo "  e, edit         d, rm, delete       cat, show"
    echo ""
    echo "Examples:"
    echo "  ai-prompt save code-review"
    echo "  ai-prompt use code-review"
    echo "  ai-prompt list"
    echo "  ai-prompt edit code-review"
    echo ""
    echo "Tab completion is available for prompt names."
    echo "Works with any AI chat service: Amazon Q, Claude, ChatGPT, Gemini, etc."
}
