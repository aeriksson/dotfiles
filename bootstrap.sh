#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

readonly PROGDIR=$(cd "$(dirname "$0")" && pwd)
readonly ZSHDIR="${PROGDIR}/zsh"
readonly VIMDIR="${PROGDIR}/vim"
readonly GITDIR="${PROGDIR}/git"
readonly TMUXDIR="${PROGDIR}/tmux"
readonly PLATFORM=$(uname)

readonly HOMEBREW_URL="https://raw.github.com/Homebrew/homebrew/go/install"
readonly CURL_FLAGS="-fsSL"

is_cmd() { hash "$1" 2> /dev/null && return 0 || return 1 }

is_dir() { [[ -d "$1" ]] && return 0 || return 1 }

fail() { echo "ERROR: $1"; exit 1 }

add_link() {
    local source=$1
    local target=$2

    if [[ ! -L "$target" || $(readlink "$target") != "$source" ]]; then
        ln -sni "$source" "$target"
    fi
}

setup_homebrew() {
    is_cmd homebrew || ruby -e "$(curl ${CURL_FLAGS} ${HOMEBREW_URL})"
}

install_cmd() {
    local cmd=$1

    if [[ "$PLATFORM" == "Darwin" ]]; then
        setup_homebrew
        brew install "$cmd"
    elif [[ "$PLATFORM" == "Linux" ]]; then
        if is_cmd yum; then
            sudo yum install "$cmd"
        else
            fail "Unknown package manager"
        fi
    else
         fail "Unknown OS."
    fi
}

setup_git() {
    add_link "${GITDIR}/gitignore_global" "${HOME}/.gitignore_global"
    add_link "${GITDIR}/gitconfig" "${HOME}/.gitconfig"
}

setup_vim() {
    is_cmd vim || install_cmd vim
    add_link "${VIMDIR}/vimrc" "${HOME}/.vimrc"
    add_link "${VIMDIR}/Vundle.vim/" "${HOME}/.vim/bundle/Vundle.vim"
    mkdir -p "${HOME}/.vim/undodir"
    vim +PluginInstall +qall
}

setup_zsh() {
    is_cmd zsh || install_cmd zsh
    add_link "${ZSHDIR}/oh-my-zsh/" "${HOME}/.oh-my-zsh"
    add_link "${ZSHDIR}/themes" "${ZSHDIR}/oh-my-zsh/custom/themes"
    for plugin in "${ZSHDIR}/plugins/"*; do
        local dest="${ZSHDIR}/oh-my-zsh/custom/plugins/$(basename $plugin)"
        add_link "$plugin" "$dest"
    done
    for script in "${ZSHDIR}/"*.zsh; do
        local dest="${ZSHDIR}/oh-my-zsh/custom/$(basename $script)"
        add_link "$script" "$dest"
    done
    add_link "${ZSHDIR}/zshrc" "${HOME}/.zshrc"
    add_link "${PROGDIR}/profile" "${HOME}/.profile"
    add_link "${PROGDIR}/aliases" "${HOME}/.aliases"
}

setup_tmux() {
    if [[ "$PLATFORM" == "Darwin" ]]; then
        is_cmd reattach-to-user-namespace || install_cmd reattach-to-user-namespace
        add_link "${TMUXDIR}/tmux.osx.conf" "${HOME}/.tmux.platform.conf"
    fi
    add_link "${TMUXDIR}/tmux.conf" "${HOME}/.tmux.conf"
}

setup_git
setup_vim
setup_zsh
setup_tmux
