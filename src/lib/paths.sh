#!/bin/sh
# lib/paths.sh — shared path registry for dots shell code
# POSIX sh. Source this file after exporting REPO_ROOT.

_path_repo_root() {
    printf '%s' "${REPO_ROOT:?REPO_ROOT required}"
}

_path_home() {
    printf '%s' "${HOME:?HOME required}"
}

path_repo_file() {
    _prf_rel="${1:?path_repo_file: relative path required}"
    printf '%s/%s' "$(_path_repo_root)" "${_prf_rel}"
}

path_src_lib() {
    _psl_name="${1:?path_src_lib: library name required}"
    path_repo_file "src/lib/${_psl_name}"
}

path_command() {
    _pc_name="${1:?path_command: command name required}"
    path_repo_file "src/commands/${_pc_name}.sh"
}

path_install_wrapper() {
    path_repo_file "src/install"
}

path_manifest() {
    _pm_root="${1:-$(_path_repo_root)}"
    printf '%s/manifest.json' "${_pm_root}"
}

path_install_config() {
    path_repo_file "config/install.conf.yaml"
}

path_brewfile() {
    path_repo_file "config/Brewfile"
}

path_themes_dir() {
    path_repo_file "content/themes"
}

path_themes_index() {
    path_repo_file "content/themes/index.yaml"
}

path_theme_config() {
    _ptc_theme="${1:?path_theme_config: theme required}"
    _ptc_flavor="${2:?path_theme_config: flavor required}"
    path_repo_file "content/themes/${_ptc_theme}-${_ptc_flavor}.yaml"
}

path_dotbot_config_files() {
    _pdc_install="$(path_install_config)"
    [ -f "${_pdc_install}" ] && printf '%s\n' "${_pdc_install}"
    _pdc_themes_dir="$(path_themes_dir)"
    [ -d "${_pdc_themes_dir}" ] || return 0
    find "${_pdc_themes_dir}" -maxdepth 1 -type f -name '*.yaml' 2>/dev/null | sort
}

path_content_tmux_conf() {
    path_repo_file "content/home/.config/tmux/tmux.conf"
}

path_oh_my_posh_palettes() {
    _pomp_root="${1:-$(_path_repo_root)}"
    printf '%s/content/assets/palettes/oh-my-posh' "${_pomp_root}"
}

path_oh_my_posh_theme_dir() {
    _pompt_root="${1:?path_oh_my_posh_theme_dir: repo root required}"
    _pompt_theme="${2:?path_oh_my_posh_theme_dir: theme required}"
    printf '%s/%s' "$(path_oh_my_posh_palettes "${_pompt_root}")" "${_pompt_theme}"
}

path_dotbot_bin() {
    path_repo_file "vendor/dotbot/bin/dotbot"
}

path_dotbot_brew_plugin() {
    path_repo_file "vendor/plugins/dotbot-brew/brew.py"
}

path_dotbot_mise_plugin() {
    path_repo_file "vendor/plugins/dotbot-mise/mise.py"
}

path_vendor_dotbot() {
    path_repo_file "vendor/dotbot"
}

path_vendor_dotbot_brew() {
    path_repo_file "vendor/plugins/dotbot-brew"
}

path_vendor_dotbot_mise() {
    path_repo_file "vendor/plugins/dotbot-mise"
}

path_home_file() {
    _phf_rel="${1:?path_home_file: relative path required}"
    printf '%s/%s' "$(_path_home)" "${_phf_rel}"
}

path_home_zshrc() { path_home_file ".zshrc"; }
path_home_zprofile() { path_home_file ".zprofile"; }
path_home_zshenv() { path_home_file ".zshenv"; }
path_home_zsh_paths() { path_home_file ".config/zsh/paths.zsh"; }
path_home_tmux_conf() { path_home_file ".tmux.conf"; }

path_home_nvim_init() { path_home_file ".config/nvim/init.lua"; }
path_home_nvim_lua_dir() { path_home_file ".config/nvim/lua"; }
path_home_nvim_theme_helper() { path_home_file ".config/nvim/lua/config/dots_theme.lua"; }
path_home_tmux_config() { path_home_file ".config/tmux/tmux.conf"; }
path_home_ghostty_config() { path_home_file ".config/ghostty/config"; }
path_home_atuin_config() { path_home_file ".config/atuin/config.toml"; }
path_home_mise_config() { path_home_file ".config/mise/config.toml"; }

path_home_oh_my_posh_theme() { path_home_file ".config/oh-my-posh/config.json"; }
path_home_bat_theme() { path_home_file ".config/bat/themes/dots.tmTheme"; }
path_home_fzf_theme() { path_home_file ".config/fzf/themes/dots.sh"; }
path_home_eza_theme() { path_home_file ".config/eza/themes/dots.sh"; }
path_home_lazygit_theme() { path_home_file ".config/lazygit/config.yml"; }
path_home_bottom_theme() { path_home_file ".config/bottom/bottom.toml"; }
path_home_ghostty_theme() { path_home_file ".config/ghostty/themes/dots"; }
path_home_atuin_theme() { path_home_file ".config/atuin/themes/dots.toml"; }
