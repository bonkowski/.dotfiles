#!/bin/bash
# Setter opp en ny maskin (macOS, Linux eller WSL med Ubuntu/Debian). Kjør med:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"
#
# macOS: Homebrew og Brewfile. Linux/WSL: apt for grunnpakker, mise for resten.
#
# Uten App Store-konto på Mac (f.eks. jobbmaskin):
#   SKIP_MAS=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"
#
# Språk og verktøy som Docker (se langs/) velges i en meny der forrige valg er forhåndsvalgt,
# eller uten spørsmål:
#   LANGS="dotnet python docker" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"
#
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

DOTFILE_DIR="$HOME/.dotfiles"
REPO_HTTPS="https://github.com/bonkowski/.dotfiles.git"
REPO_SSH="git@github.com:bonkowski/.dotfiles.git"
OS="$(uname -s)"
LANGS_FILE="$HOME/.config/dotfiles/langs"
PREVIOUS_LANGS=""

APT_PACKAGES=(
  # Grunnpakker
  zsh tmux stow git curl wget ca-certificates build-essential unzip xz-utils file
  # Enkle CLI-verktøy der apt-versjonen holder
  tree jq ripgrep fzf direnv dict telnet
  # Brukes av git (pager og editor i .gitconfig), så de må ligge i PATH også utenfor zsh
  git-delta vim
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

choose_langs() {
  local available=() selected=() i n answer
  # Bare grupper som har noe å installere på dette OS-et (f.eks. er apple-container bare for Mac)
  for dir in "$DOTFILE_DIR"/langs/*/; do
    if [ "$OS" = Darwin ]; then
      [ -f "$dir/Brewfile" ] || continue
    else
      [ -f "$dir/mise.toml" ] || [ -f "$dir/apt" ] || continue
    fi
    available+=("$(basename "$dir")")
  done

  # Forhåndsvalg: LANGS hvis satt, ellers det som ble valgt sist
  local preset=""
  if [ -n "${LANGS:-}" ]; then
    preset="$(echo "$LANGS" | tr ' ,' '\n\n')"
  elif [ -f "$LANGS_FILE" ]; then
    preset="$(cat "$LANGS_FILE")"
  fi
  if [ "$preset" = alle ]; then
    preset="${available[*]}"
  fi
  for i in "${!available[@]}"; do
    selected[i]=0
    if echo "$preset" | grep -qx "${available[i]}"; then
      selected[i]=1
    fi
  done
  for n in $preset; do
    if [ ! -d "$DOTFILE_DIR/langs/$n" ]; then
      echo "ADVARSEL: Ukjent språk '$n', hopper over."
    fi
  done

  # Meny bare når LANGS ikke er satt og det finnes en terminal
  if [ -z "${LANGS:-}" ] && { : </dev/tty; } 2>/dev/null; then
    while true; do
      echo
      echo "Velg språk og verktøy. Skriv nummer for å slå av/på (flere med mellomrom), 'a' for alle, 'i' for ingen."
      echo "Trykk Enter når du er ferdig."
      for i in "${!available[@]}"; do
        if [ "${selected[i]}" = 1 ]; then
          printf '  %d) [x] %s\n' $((i + 1)) "${available[i]}"
        else
          printf '  %d) [ ] %s\n' $((i + 1)) "${available[i]}"
        fi
      done
      read -r -p "> " answer </dev/tty
      if [ -z "$answer" ]; then
        break
      fi
      for n in $(echo "$answer" | tr ' ,' '\n\n'); do
        if [ "$n" = a ] || [ "$n" = i ]; then
          for i in "${!available[@]}"; do
            selected[i]=$([ "$n" = a ] && echo 1 || echo 0)
          done
        elif [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#available[@]}" ]; then
          i=$((n - 1))
          selected[i]=$((1 - selected[i]))
        else
          echo "Ugyldig valg: $n"
        fi
      done
    done
  fi

  mkdir -p "$(dirname "$LANGS_FILE")"
  if [ -f "$LANGS_FILE" ]; then
    PREVIOUS_LANGS="$(cat "$LANGS_FILE")"
  fi
  : >"$LANGS_FILE"
  for i in "${!available[@]}"; do
    if [ "${selected[i]}" = 1 ]; then
      echo "${available[i]}" >>"$LANGS_FILE"
    fi
  done
  echo "Valgt: $(tr '\n' ' ' <"$LANGS_FILE")"
}

# Pakker en gruppe installerer: brew-navn på Mac, "mise:<verktøy>" og "apt:<pakke>" på Linux
lang_packages() {
  local dir="$DOTFILE_DIR/langs/$1"
  if [ "$OS" = Darwin ]; then
    if [ -f "$dir/Brewfile" ]; then
      sed -nE 's/^brew "([^"]+)".*/\1/p' "$dir/Brewfile"
    fi
  else
    if [ -f "$dir/mise.toml" ]; then
      sed -nE 's/^"?([^"= ]+)"? *=.*/mise:\1/p' "$dir/mise.toml"
    fi
    if [ -f "$dir/apt" ]; then
      grep -vE '^\s*(#|$)' "$dir/apt" | sed 's/^/apt:/'
    fi
  fi
}

remove_deselected_langs() {
  local lang removed=() packages=() keep package answer

  for lang in $PREVIOUS_LANGS; do
    if ! grep -qx "$lang" "$LANGS_FILE"; then
      removed+=("$lang")
    fi
  done
  if [ ${#removed[@]} -eq 0 ]; then
    return
  fi

  # Pakker som fortsatt brukes av et valgt språk (f.eks. java for både clojure og kotlin) beholdes
  keep="$(while read -r lang; do lang_packages "$lang"; done <"$LANGS_FILE")"
  for lang in "${removed[@]}"; do
    for package in $(lang_packages "$lang"); do
      if ! echo "$keep" | grep -qx "$package"; then
        packages+=("$package")
      fi
    done
  done

  echo
  echo "Fjernet fra valget: $(printf '%s ' "${removed[@]}")"
  if [ ${#packages[@]} -eq 0 ]; then
    return
  fi
  echo "Dette kan avinstalleres: $(printf '%s ' "${packages[@]}")"
  if [ -n "${LANGS:-}" ] || ! { : </dev/tty; } 2>/dev/null; then
    echo "Avinstallerer ikke uten bekreftelse. Kjør scriptet interaktivt for å avinstallere."
    return
  fi
  read -r -p "Avinstallere? [J/n] " answer </dev/tty
  case "$answer" in
    [nN]*) return ;;
  esac

  for package in "${packages[@]}"; do
    case "$package" in
      apt:*) sudo apt-get remove -y "${package#apt:}" ;;
      mise:*) mise prune --yes "${package#mise:}" ;;
      *) brew uninstall "$package" ;;
    esac || echo "ADVARSEL: Klarte ikke å avinstallere $package."
  done
}

link_lang_mise_configs() {
  local conf_dir="$HOME/.config/mise/conf.d" lang

  # Fjerner lenker til språk som ikke lenger er valgt
  find "$conf_dir" -maxdepth 1 -type l -name 'lang-*.toml' -delete
  while read -r lang; do
    if [ -f "$DOTFILE_DIR/langs/$lang/mise.toml" ]; then
      ln -s "$DOTFILE_DIR/langs/$lang/mise.toml" "$conf_dir/lang-$lang.toml"
    fi
  done <"$LANGS_FILE"
}

install_lang_apt_packages() {
  local lang packages=()
  while read -r lang; do
    if [ -f "$DOTFILE_DIR/langs/$lang/apt" ]; then
      packages+=($(grep -vE '^\s*(#|$)' "$DOTFILE_DIR/langs/$lang/apt"))
    fi
  done <"$LANGS_FILE"

  if [ ${#packages[@]} -gt 0 ]; then
    echo "Installerer apt-pakker for valgte språk og verktøy..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
  fi
}

# Kjører langs/<gruppe>/post-install-mac.sh eller -linux.sh, f.eks. oppsett av Docker
run_lang_post_install() {
  local lang hook suffix=linux
  if [ "$OS" = Darwin ]; then
    suffix=mac
  fi
  while read -r lang; do
    hook="$DOTFILE_DIR/langs/$lang/post-install-$suffix.sh"
    if [ -f "$hook" ]; then
      bash "$hook" || echo "ADVARSEL: $hook feilet."
    fi
  done <"$LANGS_FILE"
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
  for config in "$HOME"/.config/mise/conf.d/*.toml; do
    mise trust "$config"
  done
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
  choose_langs
  stow_all

  if [ "$OS" = Darwin ]; then
    remove_deselected_langs
    install_brew_bundle
    run_lang_post_install
  else
    link_lang_mise_configs
    install_lang_apt_packages
    install_mise_tools
    remove_deselected_langs
    run_lang_post_install
    set_default_shell
  fi

  install_oh_my_zsh
  echo "Ferdig! Start en ny terminal. tmux-plugins installeres automatisk første gang tmux startes."
}

main
