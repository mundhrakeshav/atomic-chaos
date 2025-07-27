# Zsh completion script for the project Makefile

_aptos_play_make_completions() {
    local -a targets
    targets=(
        "start-node"
        "compile-dev"
        "test-dev"
        "publish-dev"
        "clean-dev"
        "get_by_hash"
        "run"
        "view"
    )

    local -a get_by_hash_args=("NETWORK=" "TXN_HASH=")
    local -a run_view_args=("ACCOUNT=" "MODULE=" "FUNCTION=" "ARGS=")

    # The current word being completed is in COMP_CWORD
    # The command line words are in the COMP_WORDS array
    # In zsh, it's CURRENT and words
    
    # If we are completing the second word (the make target itself)
    if [ "$CURRENT" -eq 2 ]; then
        compadd -a targets
        return
    fi

    # If we are completing arguments for a specific target
    if [ "$CURRENT" -gt 2 ]; then
        case "${words[2]}" in
            "get_by_hash")
                compadd -a get_by_hash_args
                ;;
            "run" | "view")
                compadd -a run_view_args
                ;;
            *)
                # Fallback to default file completion for other commands
                _files
                ;;
        esac
        return
    fi
}

# Register the completion function for the 'make' command
compdef _aptos_play_make_completions make 