# .dotfiles

Oppsett for macOS, Linux og WSL (Ubuntu/Debian).

## Installasjon

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"
```

Scriptet installerer pakker, kloner repoet til `~/.dotfiles` og lenker konfigurasjonen på plass med stow.

- **macOS:** Homebrew og `homebrew/Brewfile`
- **Linux/WSL:** apt for grunnpakker, mise for resten (`mise-linux/`)

Underveis får du en meny for å velge språk og verktøy, som dotnet, python og docker (se `langs/`).
Valget lagres i `~/.config/dotfiles/langs`. Kjør scriptet på nytt for å endre det, og språk du
fjerner kan avinstalleres.

### Valg

```bash
# Velg språk og verktøy uten meny
LANGS="dotnet python docker" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"

# Mac uten App Store-konto (f.eks. jobbmaskin)
SKIP_MAS=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/bonkowski/.dotfiles/main/setup.sh)"
```
