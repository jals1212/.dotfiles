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

# Add .NET Core SDK tools
export PATH="$PATH:~/.dotnet/tools"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
