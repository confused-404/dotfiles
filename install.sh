#!/usr/bin/env bash
set -e

DOTFILES="$HOME/dev/dotfiles"

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
