#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

readonly PROGDIR=$(cd "$(dirname "$0")" && pwd)
readonly ZSHDIR="${PROGDIR}/zsh"
readonly VIMDIR="${PROGDIR}/vim"
readonly GITDIR="${PROGDIR}/git"
readonly PLATFORM=$(uname)

readonly HOMEBREW_URL="https://raw.github.com/Homebrew/homebrew/go/install"
readonly CURL_FLAGS="-fsSL"

link_file() {
    local source=$1
    local target=$2

    if [[ ! -L "$target" || $(readlink "$target") != "$source" ]]; then
        ln -sni "$source" "$target"
    fi
}

setup_homebrew() {
    command_exists homebrew ||
        \ ruby -e "$(curl ${CURL_FLAGS} ${HOMEBREW_URL})"
}

command_exists() {
    local command=$1

    if hash "$command" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

is_dir() {
    local dir=$1

    [[ -d "$dir" ]]
}

install_command() {
    local command=$1

    if [[ "$PLATFORM" == "Darwin" ]]; then
        setup_homebrew
        brew install "$command"
    elif [[ "$PLATFORM" == "Linux" ]]; then
        if command_exists yum; then
            sudo yum install "$command"
        else
            echo "ERROR: unknown package manager."
            exit 1
        fi
    else
        echo "ERROR: unknown OS."
        exit 1
    fi
}

setup_git() {
    link_file "${GITDIR}/gitignore_global" "${HOME}/.gitignore_global"
    link_file "${GITDIR}/gitconfig" "${HOME}/.gitconfig"
}

setup_vim() {
    command_exists vim || install_command vim
    link_file "${VIMDIR}/vimrc" "${HOME}/.vimrc"
    link_file "${VIMDIR}/Vundle.vim/" "${HOME}/.vim/bundle/Vundle.vim"
    mkdir -p "${HOME}/.vim/undodir"
    vim +PluginInstall +qall
}

setup_zsh() {
    command_exists zsh || install_command zsh
    link_file "${ZSHDIR}/oh-my-zsh/" "${HOME}/.oh-my-zsh"
    link_file "${ZSHDIR}/themes" "${ZSHDIR}/oh-my-zsh/custom/themes"
    for plugin in "${ZSHDIR}/plugins/"*; do
        local dest="${ZSHDIR}/oh-my-zsh/custom/plugins/$(basename $plugin)"
        link_file "$plugin" "$dest"
    done
    for script in "${ZSHDIR}/"*.zsh; do
        local dest="${ZSHDIR}/oh-my-zsh/custom/$(basename $script)"
        link_file "$script" "$dest"
    done
    link_file "${ZSHDIR}/zshrc" "${HOME}/.zshrc"
    link_file "${PROGDIR}/profile" "${HOME}/.profile"
    link_file "${PROGDIR}/aliases" "${HOME}/.aliases"
}

setup_git
setup_vim
setup_zsh
