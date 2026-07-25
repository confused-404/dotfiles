#!/usr/bin/env bash
set -e

DOTFILES="$HOME/dev/dotfiles"
INSTALL_ALL=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [--all]

Link the default dotfiles into the current user's home directory.

Options:
  --all    Also install every tracked software configuration, including WezTerm.
  -h, --help
           Show this help message.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --all)
            INSTALL_ALL=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

# TMUX
ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"

# BASH
ln -sf "$DOTFILES/bash/.bashrc" "$HOME/.bashrc"

# GIT
ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"

# NVIM
mkdir -p ~/.config
ln -sfn "$DOTFILES/nvim" "$HOME/.config/nvim"

# CODEX
mkdir -p ~/.codex
ln -sfn "$DOTFILES/codex" "$HOME/.codex"

# GENERIC AGENTS
ln -sf "$DOTFILES/codex/AGENTS.md" "$HOME/AGENTS.md"

if [ "$INSTALL_ALL" = true ]; then
    # WEZTERM
    ln -sf "$DOTFILES/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
fi

echo "Running plugin post-install hooks..."

run_markdown_preview_install() {
    local plugin

    plugin=$(find "$HOME/.local/share/nvim/site/pack" \
        -type d \
        -name markdown-preview.nvim \
        | head -n1)

    if [ -z "$plugin" ]; then
        echo "markdown-preview.nvim not installed"
        return
    fi

    echo "Building markdown-preview.nvim..."

    if [ ! -d "$plugin/app" ]; then
        echo "markdown-preview.nvim app directory missing"
        return
    fi

    (
        cd "$plugin/app" || exit 1
        npx --yes yarn install
        npx --yes yarn build
    )
}

run_markdown_preview_install

echo "Dotfiles linked."
