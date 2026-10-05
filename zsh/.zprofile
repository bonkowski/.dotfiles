# Homebrew (bare Mac) – /opt/homebrew på Apple Silicon, /usr/local på Intel
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done
unset brew_bin

if [[ "$OSTYPE" == darwin* ]]; then
  # Added by Toolbox App
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
  export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
fi

# For Poetry
export PATH="$PATH:$HOME/.local/bin"
