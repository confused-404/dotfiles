# Dotfiles

This repository contains personal shell, editor, terminal multiplexer, Git, Codex, and WezTerm configuration.

## Installation

The installer expects this repository at `~/dev/dotfiles`.
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
