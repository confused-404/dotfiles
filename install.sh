#!/usr/bin/env bash
set -e

DOTFILES="$HOME/dev/dotfiles"

ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES/bash/.bashrc" "$HOME/.bashrc"
ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"

echo "Dotfiles linked."
