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
ln -s "$DOTFILES/nvim" "$HOME/.config/nvim"

# CODEX
mkdir -p ~/.codex
ln -s "$DOTFILES/codex" "$HOME/.codex"

# GENERIC AGENTS
ln -s "$DOTFILES/codex/AGENTS.md" "$HOME/AGENTS.md"

echo "Dotfiles linked."
