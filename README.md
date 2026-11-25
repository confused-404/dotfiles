# Dotfiles

This repository contains personal shell, editor, terminal multiplexer, Git, Codex, and WezTerm configuration.

## Installation

Run the installer from this checkout on Ubuntu or Kubuntu.
Kubuntu 24.04 uses the Ubuntu 24.04 package profile, which installs clipboard tools for Wayland and X11.
The installer backs up existing configurations beside their original paths before linking this checkout.
Run the default installation to link the standard configurations into your home directory:

```sh
./install.sh
```

The default installation links Bash, Git, tmux, Neovim, Codex, and the shared `AGENTS.md` file.
To also link every tracked software configuration, including WezTerm, run:

```sh
./install.sh --all
```

Use `./install.sh --help` to view the available options.
