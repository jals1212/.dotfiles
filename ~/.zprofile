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

# asdf
if [[ ! -z $(command -v asdf) ]]; then
  path=(~/.asdf/shims $path)
fi
# asdf goland
source ~/.asdf/plugins/golang/set-env.zsh

# bun
if [[ ! -z $(command -v bun) ]]; then
  path=(~/.bun/bin $path)
fi
# bun completions
[ -s "~/.bun/_bun" ] && source "~/.bun/_bun"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
