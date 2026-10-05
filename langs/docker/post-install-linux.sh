#!/bin/bash
# Lar brukeren kjøre docker uten sudo, og starter tjenesten
set -euo pipefail

if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  echo "Docker: logg ut og inn igjen (i WSL: 'wsl --shutdown') for å bruke docker uten sudo."
fi

if [ -d /run/systemd/system ]; then
  sudo systemctl enable --now docker
else
  # WSL uten systemd
  sudo service docker start || true
  echo "Docker: systemd er ikke aktivt. Start docker med 'sudo service docker start', eller slå på systemd i /etc/wsl.conf."
fi
