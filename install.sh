#!/usr/bin/env bash
set -e

DOTFILES="$HOME/dev/dotfiles"

ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES/bash/.bashrc" "$HOME/.bashrc"
ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
mkdir -p ~/.config
ln -s "$DOTFILES/nvim" "$HOME/.config/nvim"

echo "Dotfiles linked."
