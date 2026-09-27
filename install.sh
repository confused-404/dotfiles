#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
INSTALL_ALL=false
INSTALL_PACKAGES=true
INSTALL_PLUGINS=true
ASSUME_YES=false
DRY_RUN=false
UBUNTU_VERSION=""
BACKUP_SUFFIX=$(date +%Y%m%d-%H%M%S)
NEOVIM_TEMP_DIR=""
RUSTUP_TEMP_FILE=""
TREE_SITTER_MIN_VERSION=0.26.1

cleanup() {
    if [ -n "$NEOVIM_TEMP_DIR" ] && [ -d "$NEOVIM_TEMP_DIR" ]; then
        case "$NEOVIM_TEMP_DIR" in
            "${TMPDIR:-/tmp}"/dotfiles-neovim.*)
                rm -rf -- "$NEOVIM_TEMP_DIR"
                ;;
            *)
                warn "Refusing to remove unexpected temporary path: $NEOVIM_TEMP_DIR"
                ;;
        esac
    fi

    if [ -n "$RUSTUP_TEMP_FILE" ] && [ -f "$RUSTUP_TEMP_FILE" ]; then
        case "$RUSTUP_TEMP_FILE" in
            "${TMPDIR:-/tmp}"/dotfiles-rustup.*)
                rm -f -- "$RUSTUP_TEMP_FILE"
                ;;
            *)
                warn "Refusing to remove unexpected temporary path: $RUSTUP_TEMP_FILE"
                ;;
        esac
    fi
}

trap cleanup EXIT

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Install the Ubuntu dependencies and link this repository into the current
user's home directory. When run interactively, the installer asks which
Ubuntu release it should configure.

Options:
  --all                     Also link every tracked configuration, including WezTerm.
  --ubuntu-version VERSION  Use VERSION without prompting (for example, 22.04).
  --skip-packages           Do not install apt packages, Neovim, Rust, or Tree-sitter CLI.
  --skip-plugins            Do not bootstrap Neovim plugins.
  -y, --yes                 Accept installer confirmation prompts.
  --dry-run                 Print the actions without changing the system.
  -h, --help                Show this help message.
EOF
}

say() {
    printf '%s\n' "$*"
}

warn() {
    printf 'Warning: %s\n' "$*" >&2
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

run() {
    if [ "$DRY_RUN" = true ]; then
        print_command "$@"
        return
    fi

    "$@"
}

run_as_root() {
    if [ "${EUID}" -eq 0 ]; then
        run "$@"
    else
        run sudo "$@"
    fi
}

confirm() {
    local prompt=$1
    local answer

    if [ "$ASSUME_YES" = true ]; then
        return 0
    fi

    if [ ! -t 0 ]; then
        return 0
    fi

    read -r -p "$prompt [Y/n] " answer || return 1
    case "$answer" in
        ""|y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

detect_ubuntu_version() {
    if [ ! -r /etc/os-release ]; then
        return
    fi

    (
        # shellcheck disable=SC1091
        . /etc/os-release
        if [ "${ID:-}" = ubuntu ]; then
            printf '%s' "${VERSION_ID:-}"
        fi
    )
}

choose_ubuntu_version() {
    local detected_version
    local selected_version

    if [ -z "$UBUNTU_VERSION" ]; then
        detected_version=$(detect_ubuntu_version)

        if [ -t 0 ]; then
            if [ -n "$detected_version" ]; then
                read -r -p "Ubuntu version [$detected_version]: " selected_version
                UBUNTU_VERSION=${selected_version:-$detected_version}
            else
                read -r -p "Ubuntu version (for example, 22.04): " UBUNTU_VERSION
            fi
        elif [ -n "$detected_version" ]; then
            UBUNTU_VERSION=$detected_version
        else
            die "could not detect Ubuntu. Pass --ubuntu-version VERSION."
        fi
    fi

    case "$UBUNTU_VERSION" in
        22) UBUNTU_VERSION=22.04 ;;
        24) UBUNTU_VERSION=24.04 ;;
        26) UBUNTU_VERSION=26.04 ;;
    esac

    if [[ ! "$UBUNTU_VERSION" =~ ^[0-9]{2}\.[0-9]{2}$ ]]; then
        die "invalid Ubuntu version '$UBUNTU_VERSION'. Expected a value such as 22.04."
    fi
}

describe_ubuntu_profile() {
    case "$UBUNTU_VERSION" in
        22.04)
            say "Using the Ubuntu 22.04 profile (Jammy)."
            say "Current Neovim and Tree-sitter tools will be installed locally when needed."
            ;;
        24.04)
            say "Using the Ubuntu 24.04 profile (Noble)."
            say "Current Neovim and Tree-sitter tools will be installed locally when needed."
            ;;
        26.04)
            say "Using the Ubuntu 26.04 profile (Resolute)."
            say "Current Neovim and Tree-sitter tools will be installed locally when needed."
            ;;
        *)
            warn "Ubuntu $UBUNTU_VERSION has not been tested with this installer."
            if ! confirm "Continue with the generic Ubuntu profile?"; then
                exit 1
            fi
            ;;
    esac
}

install_apt_packages() {
    local packages=(
        ca-certificates
        curl
        fd-find
        gcc
        g++
        git
        gzip
        libssl-dev
        make
        nodejs
        npm
        pkg-config
        ripgrep
        tmux
        unzip
        wl-clipboard
        xclip
    )

    command -v apt-get >/dev/null 2>&1 || die "apt-get was not found. This installer supports Ubuntu only."
    if [ "${EUID}" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        die "sudo is required to install Ubuntu packages."
    fi

    say "Installing Ubuntu packages..."
    run_as_root apt-get update
    run_as_root apt-get install -y "${packages[@]}"
}

has_compatible_neovim() {
    command -v nvim >/dev/null 2>&1 || return 1
    nvim --headless -u NONE -i NONE \
        "+lua if vim.pack == nil then vim.cmd('cquit 1') end" \
        "+qa" >/dev/null 2>&1
}

install_neovim() {
    local machine
    local archive_arch
    local archive_name
    local release_api="https://api.github.com/repos/neovim/neovim/releases/latest"
    local download_url
    local expected_digest
    local extracted_dir
    local install_dir="$HOME/.local/opt/nvim"
    local backup_path

    if has_compatible_neovim; then
        say "Neovim already provides vim.pack; keeping $(command -v nvim)."
        return
    fi

    machine=$(uname -m)
    case "$machine" in
        x86_64|amd64) archive_arch=x86_64 ;;
        aarch64|arm64) archive_arch=arm64 ;;
        *) die "Neovim does not publish a supported Linux archive for '$machine'." ;;
    esac

    archive_name="nvim-linux-${archive_arch}.tar.gz"

    if [ "$DRY_RUN" = true ]; then
        say "Would install the latest official Neovim release into $install_dir."
        return
    fi

    say "Installing a current Neovim into $install_dir..."
    NEOVIM_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-neovim.XXXXXX")

    curl --fail --location --retry 3 \
        --output "$NEOVIM_TEMP_DIR/release.json" \
        "$release_api"
    download_url=$(node -e '
        const release = require(process.argv[1]);
        const asset = release.assets.find(({ name }) => name === process.argv[2]);
        if (!asset) process.exit(1);
        process.stdout.write(asset.browser_download_url);
    ' "$NEOVIM_TEMP_DIR/release.json" "$archive_name")
    expected_digest=$(node -e '
        const release = require(process.argv[1]);
        const asset = release.assets.find(({ name }) => name === process.argv[2]);
        if (!asset || !asset.digest || !asset.digest.startsWith("sha256:")) process.exit(1);
        process.stdout.write(asset.digest.slice("sha256:".length));
    ' "$NEOVIM_TEMP_DIR/release.json" "$archive_name")

    [ -n "$download_url" ] || die "the latest Neovim release has no $archive_name asset."
    [ -n "$expected_digest" ] || die "the latest Neovim release has no SHA-256 digest for $archive_name."

    curl --fail --location --retry 3 \
        --output "$NEOVIM_TEMP_DIR/$archive_name" \
        "$download_url"
    printf '%s  %s\n' "$expected_digest" "$NEOVIM_TEMP_DIR/$archive_name" | sha256sum --check -
    tar -xzf "$NEOVIM_TEMP_DIR/$archive_name" -C "$NEOVIM_TEMP_DIR"

    extracted_dir="$NEOVIM_TEMP_DIR/nvim-linux-${archive_arch}"
    [ -d "$extracted_dir" ] || die "the Neovim archive had an unexpected layout."

    mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
    if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
        backup_path="$install_dir.backup-$BACKUP_SUFFIX"
        say "Backing up the existing Neovim installation to $backup_path."
        mv -- "$install_dir" "$backup_path"
    fi

    mv -- "$extracted_dir" "$install_dir"
    backup_and_link "$install_dir/bin/nvim" "$HOME/.local/bin/nvim"
    rm -rf -- "$NEOVIM_TEMP_DIR"
    NEOVIM_TEMP_DIR=""
    hash -r

    "$HOME/.local/bin/nvim" --version | sed -n '1p'
}

version_at_least() {
    local actual=$1
    local minimum=$2
    local lowest

    lowest=$(printf '%s\n%s\n' "$minimum" "$actual" | sort -V | sed -n '1p')
    [ "$lowest" = "$minimum" ]
}

tree_sitter_works() {
    local output
    local version

    command -v tree-sitter >/dev/null 2>&1 || return 1
    output=$(tree-sitter --version 2>/dev/null) || return 1
    version=${output#tree-sitter }
    version=${version%% *}

    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    version_at_least "$version" "$TREE_SITTER_MIN_VERSION"
}

install_rust_toolchain() {
    export PATH="$HOME/.cargo/bin:$PATH"

    if command -v rustup >/dev/null 2>&1; then
        say "Updating the Rust stable toolchain..."
        run rustup toolchain install stable --profile minimal
        run rustup default stable
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        say "Would install the Rust stable toolchain with rustup."
        return
    fi

    say "Installing the Rust stable toolchain with rustup..."
    RUSTUP_TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/dotfiles-rustup.XXXXXX")
    curl --proto '=https' --tlsv1.2 --fail --silent --show-error \
        --output "$RUSTUP_TEMP_FILE" \
        https://sh.rustup.rs
    sh "$RUSTUP_TEMP_FILE" -y --profile minimal --no-modify-path
    rm -f -- "$RUSTUP_TEMP_FILE"
    RUSTUP_TEMP_FILE=""
    hash -r

    command -v cargo >/dev/null 2>&1 || die "rustup completed but cargo is unavailable."
}

remove_npm_tree_sitter_cli() {
    if ! command -v npm >/dev/null 2>&1; then
        return
    fi

    if ! npm list --global --depth=0 tree-sitter-cli >/dev/null 2>&1; then
        return
    fi

    say "Removing the incompatible npm-global Tree-sitter CLI..."
    run npm uninstall --global tree-sitter-cli
    hash -r
}

install_tree_sitter_cli() {
    local existing_path
    local cargo_bin

    if tree_sitter_works; then
        say "Tree-sitter CLI is compatible; keeping $(command -v tree-sitter)."
        return
    fi

    existing_path=$(command -v tree-sitter 2>/dev/null || true)
    if [ -n "$existing_path" ]; then
        warn "The Tree-sitter CLI at $existing_path is broken or older than $TREE_SITTER_MIN_VERSION."
    fi

    remove_npm_tree_sitter_cli

    # The npm release is a prebuilt binary and may require a newer glibc than
    # the host. Cargo builds against the current Ubuntu release instead.
    install_rust_toolchain

    cargo_bin="$HOME/.cargo/bin/cargo"
    if [ "$DRY_RUN" = false ] && [ ! -x "$cargo_bin" ]; then
        cargo_bin=$(command -v cargo || true)
        [ -n "$cargo_bin" ] || die "cargo is required to build Tree-sitter CLI."
    fi

    say "Building Tree-sitter CLI locally for Ubuntu $UBUNTU_VERSION..."
    run "$cargo_bin" install --locked --force tree-sitter-cli

    if [ "$DRY_RUN" = true ]; then
        return
    fi

    hash -r
    if ! "$HOME/.cargo/bin/tree-sitter" --version; then
        die "the locally built Tree-sitter CLI failed to start."
    fi

    backup_and_link "$HOME/.cargo/bin/tree-sitter" "$HOME/.local/bin/tree-sitter"
    hash -r
    tree_sitter_works || die "the new Tree-sitter CLI is not available on PATH."
    say "Tree-sitter CLI was rebuilt against this system's glibc."
}

backup_and_link() {
    local source=$1
    local destination=$2
    local backup_path
    local current_target

    if [ -L "$destination" ]; then
        current_target=$(readlink "$destination")
        if [ "$current_target" = "$source" ]; then
            say "Already linked: $destination"
            return
        fi
    fi

    if [ -e "$destination" ] || [ -L "$destination" ]; then
        backup_path="$destination.backup-$BACKUP_SUFFIX"
        say "Backing up $destination to $backup_path."
        run mv -- "$destination" "$backup_path"
    fi

    run mkdir -p "$(dirname -- "$destination")"
    run ln -s "$source" "$destination"
    say "Linked $destination -> $source"
}

link_dotfiles() {
    say "Linking dotfiles from $DOTFILES..."

    backup_and_link "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
    backup_and_link "$DOTFILES/bash/.bashrc" "$HOME/.bashrc"
    backup_and_link "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
    backup_and_link "$DOTFILES/nvim" "$HOME/.config/nvim"

    # Keep Codex's runtime directory intact and link only the tracked config.
    backup_and_link "$DOTFILES/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
    backup_and_link "$DOTFILES/codex/AGENTS.md" "$HOME/AGENTS.md"

    if [ "$INSTALL_ALL" = true ]; then
        backup_and_link "$DOTFILES/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
    fi
}

run_markdown_preview_install() {
    local pack_dir="$HOME/.local/share/nvim/site/pack"
    local plugin

    if [ ! -d "$pack_dir" ]; then
        warn "Neovim's package directory does not exist; skipping markdown-preview build."
        return
    fi

    plugin=$(find "$pack_dir" -type d -name markdown-preview.nvim -print -quit)
    if [ -z "$plugin" ]; then
        warn "markdown-preview.nvim was not installed; skipping its build."
        return
    fi

    if [ ! -d "$plugin/app" ]; then
        warn "markdown-preview.nvim has no app directory; skipping its build."
        return
    fi

    if ! command -v npx >/dev/null 2>&1; then
        warn "npx is unavailable; skipping the markdown-preview build."
        return
    fi

    say "Building markdown-preview.nvim..."
    (
        cd "$plugin/app"
        npx --yes yarn install
        npx --yes yarn build
    )
}

bootstrap_neovim() {
    if [ "$DRY_RUN" = true ]; then
        say "Would start Neovim once and build markdown-preview.nvim."
        return
    fi

    if ! command -v nvim >/dev/null 2>&1; then
        warn "Neovim is unavailable; skipping plugin bootstrap."
        return
    fi

    say "Starting Neovim once to install configured plugins..."
    if ! nvim --headless "+qa"; then
        warn "Neovim plugin bootstrap failed. Run nvim and :checkhealth for details."
        return
    fi

    run_markdown_preview_install
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --all)
            INSTALL_ALL=true
            ;;
        --ubuntu-version)
            [ "$#" -ge 2 ] || die "--ubuntu-version requires a value."
            UBUNTU_VERSION=$2
            shift
            ;;
        --ubuntu-version=*)
            UBUNTU_VERSION=${1#*=}
            ;;
        --skip-packages)
            INSTALL_PACKAGES=false
            ;;
        --skip-plugins)
            INSTALL_PLUGINS=false
            ;;
        -y|--yes)
            ASSUME_YES=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1 (run with --help for usage)."
            ;;
    esac
    shift
done

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

choose_ubuntu_version
describe_ubuntu_profile

if [ "$INSTALL_PACKAGES" = true ]; then
    if confirm "Install or update the required Ubuntu packages?"; then
        install_apt_packages
        install_neovim
        install_tree_sitter_cli
    else
        warn "Skipping package installation."
    fi
fi

link_dotfiles

if [ "$INSTALL_PLUGINS" = true ]; then
    bootstrap_neovim
fi

say "Dotfiles setup complete for Ubuntu $UBUNTU_VERSION."
