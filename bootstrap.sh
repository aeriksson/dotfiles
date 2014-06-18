#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

readonly PROGDIR=$(cd "$(dirname "$0")" && pwd)
readonly PLATFORM=$(uname)

readonly HOMEBREW_URL="https://raw.github.com/Homebrew/homebrew/go/install"
readonly VUNDLE_URL="https://github.com/gmarik/Vundle.vim.git"
readonly OH_MY_ZSH_URL="https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh"
readonly CURL_FLAGS="-fsSL"

readonly VUNDLE_PATH="${HOME}/.vim/bundle/Vundle.vim"

link_file() {
    local source=$1
    local target=$2

    ln -si "$source" "$target"
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
    else
        echo "ERROR: git not found."
        exit 1
    fi
}

setup_git() {
    link_file "${PROGDIR}/gitignore_global" "${HOME}/.gitignore_global"
    link_file "${PROGDIR}/gitconfig" "${HOME}/.gitconfig"
}

setup_vim() {
    command_exists vim || install_command vim
    link_file "${PROGDIR}/vimrc" "${HOME}/.vimrc"
    mkdir -p "${HOME}/.vim/undodir"
    is_dir "$VUNDLE_PATH" || git clone "$VUNDLE_URL" "$VUNDLE_PATH"
    vim +PluginInstall +qall
}

setup_zsh() {
    is_dir "${HOME}/.oh-my-zsh" || bash -c "$(curl ${CURL_FLAGS} ${OH_MY_ZSH_URL})"
    link_file "${PROGDIR}/zshrc" "${HOME}/.zshrc"
    link_file "${PROGDIR}/profile" "${HOME}/.profile"
    link_file "${PROGDIR}/aliases" "${HOME}/.aliases"
}

setup_git
setup_vim
setup_zsh
