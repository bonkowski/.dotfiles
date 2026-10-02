#!/bin/bash
# Setter opp en ny maskin. Kjør med:
#   curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh | bash
#
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

DOTFILE_DIR="$HOME/.dotfiles"
REPO_HTTPS="https://github.com/bonkowski/.dotfiles.git"
REPO_SSH="git@github.com:bonkowski/.dotfiles.git"

install_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo "Homebrew ikke funnet. Installerer Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

clone_dotfiles_repo() {
  if [ ! -d "$DOTFILE_DIR" ]; then
    # Kloner over HTTPS siden SSH-nøkkel ikke er satt opp ennå
    echo "Kloner .dotfiles-repoet til $DOTFILE_DIR..."
    git clone "$REPO_HTTPS" "$DOTFILE_DIR"
    git -C "$DOTFILE_DIR" remote set-url origin "$REPO_SSH"
  fi
}

stow_all() {
  mkdir -p "$HOME/.config"

  for dir in "$DOTFILE_DIR"/*/; do
    stow -d "$DOTFILE_DIR" -t "$HOME" "$(basename "$dir")"
  done
  stow -d "$DOTFILE_DIR" -t "$HOME/.config" .config
}

install_brew_bundle() {
  brew bundle --file "$DOTFILE_DIR/homebrew/Brewfile"
}

install_oh_my_zsh() {
  # Kjøres etter stow, så --keep-zshrc beholder .zshrc fra dotfiles
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installerer oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  fi
}

main() {
  install_homebrew
  install_stow
  clone_dotfiles_repo
  stow_all
  install_brew_bundle
  install_oh_my_zsh
  echo "Ferdig! Start en ny terminal. tmux-plugins installeres automatisk første gang tmux startes."
}

main
