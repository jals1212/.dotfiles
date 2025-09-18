#!/bin/zsh

# Homebrew
if [[ -z $(command -v brew) ]]; then
  if [[ $(arch) == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
    sudo chown -R $(whoami) $(brew --prefix)/*
  fi
fi
# Homebrew end

# asdf
if [[ ! -z $(command -v asdf) ]]; then
  path=(~/.asdf/shims $path)
fi
source ~/.asdf/plugins/golang/set-env.zsh
# asdf end

# pnpm
export PNPM_HOME="~/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# bun
if [[ ! -z $(command -v bun) ]]; then
  path=(~/.bun/bin $path)
fi
[ -s "~/.bun/_bun" ] && source "~/.bun/_bun"
# bun end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
