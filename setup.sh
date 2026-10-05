#!/bin/bash
# Setter opp en ny maskin (macOS, Linux eller WSL med Ubuntu/Debian). Kjør med:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"
#
# macOS: Homebrew og Brewfile. Linux/WSL: apt for grunnpakker, mise for resten.
#
# Uten App Store-konto på Mac (f.eks. jobbmaskin):
#   SKIP_MAS=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"
#
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

DOTFILE_DIR="$HOME/.dotfiles"
REPO_HTTPS="https://github.com/bonkowski/.dotfiles.git"
REPO_SSH="git@github.com:bonkowski/.dotfiles.git"
OS="$(uname -s)"

APT_PACKAGES=(
  # Grunnpakker
  zsh tmux stow git curl wget ca-certificates build-essential unzip xz-utils file
  # Enkle CLI-verktøy der apt-versjonen holder
  tree jq ripgrep fzf direnv dict telnet
  # Valgfrie avhengigheter for yazi
  ffmpeg p7zip-full poppler-utils imagemagick
  # Build / dev tooling
  cmake pkg-config libpq-dev
)

install_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo "Homebrew ikke funnet. Installerer Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # brew er ikke i PATH rett etter en ny installasjon
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_stow() {
  if ! command -v stow &>/dev/null; then
    brew install stow
  fi
}

install_apt_packages() {
  if ! command -v apt-get &>/dev/null; then
    echo "Fant ikke apt-get. Bare Ubuntu/Debian støttes på Linux."
    exit 1
  fi

  echo "Installerer pakker med apt..."
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"
}

clone_dotfiles_repo() {
  if [ ! -d "$DOTFILE_DIR" ]; then
    # Kloner over HTTPS siden SSH-nøkkel ikke er satt opp ennå
    echo "Kloner .dotfiles-repoet til $DOTFILE_DIR..."
    git clone "$REPO_HTTPS" "$DOTFILE_DIR"
    git -C "$DOTFILE_DIR" remote set-url origin "$REPO_SSH"
  fi
}

stow_all() {
  local packages=(git tmux zsh)

  if [ "$OS" = Darwin ]; then
    packages+=(homebrew)
  else
    packages+=(mise-linux)
    # Lages på forhånd så stow lenker selve filen, ikke hele mise-mappen inn i repoet
    mkdir -p "$HOME/.config/mise/conf.d"
  fi

  mkdir -p "$HOME/.config"
  for package in "${packages[@]}"; do
    stow -d "$DOTFILE_DIR" -t "$HOME" "$package"
  done
  stow -d "$DOTFILE_DIR" -t "$HOME/.config" .config
}

install_brew_bundle() {
  # Homebrew sender bare videre miljøvariabler med HOMEBREW_-prefiks til Brewfile
  if [ -n "${SKIP_MAS:-}" ]; then
    export HOMEBREW_SKIP_MAS=1
  fi

  # Ikke avbryt hvis enkeltpakker feiler, f.eks. apper som IT allerede har installert
  if ! brew bundle --file "$DOTFILE_DIR/homebrew/Brewfile"; then
    echo "ADVARSEL: Noen pakker i Brewfile feilet. Se over feilene, og kjør 'brew bundle --file ~/Brewfile' på nytt ved behov."
  fi
}

install_mise_tools() {
  if ! command -v mise &>/dev/null && [ ! -x "$HOME/.local/bin/mise" ]; then
    echo "Installerer mise..."
    curl -fsSL https://mise.run | sh
  fi
  export PATH="$HOME/.local/bin:$PATH"

  echo "Installerer verktøy med mise (kan ta en stund)..."
  mise trust "$HOME/.config/mise/conf.d/linux.toml"
  # Ikke avbryt hvis enkeltverktøy feiler, f.eks. pga. GitHub sin rate limit
  if ! (builtin cd "$HOME" && mise install); then
    echo "ADVARSEL: Noen verktøy feilet. Kjør 'mise install' på nytt senere, gjerne med GITHUB_TOKEN satt."
  fi
}

set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"

  if [ "${SHELL:-}" != "$zsh_path" ]; then
    echo "Setter zsh som standard-shell (krever passord)..."
    chsh -s "$zsh_path"
  fi
}

install_oh_my_zsh() {
  # Kjøres etter stow, så --keep-zshrc beholder .zshrc fra dotfiles
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installerer oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  fi
}

main() {
  case "$OS" in
    Darwin)
      install_homebrew
      install_stow
      ;;
    Linux)
      install_apt_packages
      ;;
    *)
      echo "Ukjent OS: $OS"
      exit 1
      ;;
  esac

  clone_dotfiles_repo
  stow_all

  if [ "$OS" = Darwin ]; then
    install_brew_bundle
  else
    install_mise_tools
    set_default_shell
  fi

  install_oh_my_zsh
  echo "Ferdig! Start en ny terminal. tmux-plugins installeres automatisk første gang tmux startes."
}

main
