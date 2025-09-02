#!/bin/zsh

if [ -z "$ZSH_VERSION" ]; then
    echo "This script must be run with zsh"
    exit 1
fi

set -e

echo "Installing dotfiles..."

cd ~/.dotfiles

ask_yes_no() {
    read -q "?$1 (y/N) "
    out=$?
    echo $REPLY >&2
    return $out
}

# MacOS ---

configure_macos() {
    if ask_yes_no "Do you want to set the default macOS settings?"; then
        echo "Configuring macOS..."

        # Set the computer name
        read "COMPUTER_NAME?What do you want to name your computer? "
        sudo scutil --set ComputerName ${COMPUTER_NAME}
        sudo scutil --set HostName ${COMPUTER_NAME}
        sudo scutil --set LocalHostName ${COMPUTER_NAME}

        # Disable the sound effects on boot
        sudo nvram StartupMute=%01

        # Show hidden files in Finder
        defaults write com.apple.finder AppleShowAllFiles -bool true

        # Use list view in Finder
        defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

        # Show all filename extensions
        defaults write NSGlobalDomain AppleShowAllFiles -bool true

        # Show the ~/Library folder
        chflags nohidden ~/Library

        echo "Done configuring macOS"
    fi
}

configure_macos

# Install the latest Xcode command-line tools ---

install_xcode() {
    if ask_yes_no 'Install the latest Xcode command-line tools?'; then
        echo "Installing Xcode command-line tools..."

        touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        softwareupdate -i -a
        rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

        echo "Done installing Xcode command-line tools"
    fi
}

install_xcode

# Homebrew ---

install_homebrew() {

    if [[ $(arch) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
        sudo chown -R $(whoami) $(brew --prefix)/*
    fi

    if [[ -z $(command -v brew) ]]; then
        echo "Installing Hombrew"

        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [[ $(arch) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
            sudo chown -R $(whoami) $(brew --prefix)/*
        fi

        echo "Done installing Homebrew"
    elif ask_yes_no "Homebrew is already installed, do you want to update it?"; then
        echo "Updating Homebrew"

        brew update

        echo "Done updating Homebrew"
    fi
}

install_homebrew

# Install Brewfile ---

install_brewfile() {
    if ask_yes_no "Install Homebrew packages?"; then
        echo "Installing Homebrew packages..."

        brew bundle --file="./Brewfile"

        echo "Done installing Homebrew packages"
    fi
}

install_brewfile

# Stow files ---

stow_dotfiles() {
    echo "Stowing dotfiles..."

    for dir in */; do
        stow -v -t ~ -S ${dir}
    done

    echo "Done stowing dotfiles"
}

stow_dotfiles

# Git ---

configure_git() {
    if [[ ! -z $(command -v git) ]]; then
        if ask_yes_no "Configure Git?"; then
            echo "Configuring Git..."

            read "GIT_SETUP_NAME?What's your git name? "
            read "GIT_SETUP_EMAIL?What's your git email? "

            rm -f ~/.gitconfig
            touch ~/.gitconfig
            echo '
[include]
    path = ~/.gitconfig_global
' >>~/.gitconfig

            git config --global user.name ${GIT_SETUP_NAME}
            git config --global user.email ${GIT_SETUP_EMAIL}

            echo "Done configuring Git"
        fi
    fi
}

configure_git

# SSH ---

configure_ssh() {
    if ask_yes_no "Configure SSH?"; then
        echo "Configuring SSH..."

        [ -z $(git config --global user.email) ] && read "GIT_SETUP_EMAIL?What's your email? "

        echo "WARNING: not checking for existing SSH keys\!"

        echo "Now configuring SSH keys..."
        ssh-keygen -t rsa -C ${GIT_SETUP_EMAIL}

        echo "Let's start the ssh-agent..."
        eval "$(ssh-agent -s)"

        echo "Adding SSH key..."
        ssh-add ~/.ssh/id_rsa

        echo "Done configuring SSH"
    fi
}

configure_ssh

# asdf ---

configure_asdf() {
    if [[ ! -z $(command -v asdf) ]]; then
        if ask_yes_no "Configure asdf?"; then
            echo "Configuring asdf..."

            source $(brew --prefix asdf)/libexec/asdf.sh

            asdf plugin add bun
            asdf plugin add dotnet
            asdf plugin add golang
            asdf plugin add java
            asdf plugin add nodejs
            asdf plugin add python
            asdf plugin add ruby

            asdf install

            echo "Done configuring asdf"
        fi
    fi
}

configure_asdf

# Rosetta ---

install_rosetta() {
    if [[ $(arch) == "arm64" ]]; then
        if ask_yes_no "Install Rosetta?"; then
            echo "Installing Rosetta"

            softwareupdate --install-rosetta --agree-to-license

            echo "Done installing Rosetta"
        fi
    fi
}

install_rosetta

echo "Done installing dotfiles"
