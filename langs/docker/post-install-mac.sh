#!/bin/bash
# Lar docker finne compose- og buildx-pluginene fra Homebrew (`docker compose`, `docker buildx`)
set -euo pipefail

config="$HOME/.docker/config.json"
plugins="$(brew --prefix)/lib/docker/cli-plugins"

mkdir -p "$HOME/.docker"
[ -f "$config" ] || echo '{}' >"$config"
tmp="$(mktemp)"
jq --arg dir "$plugins" '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$dir] | unique)' "$config" >"$tmp"
mv "$tmp" "$config"

echo "Docker: start VM-en med 'colima start' (eller 'brew services start colima' for autostart)."
