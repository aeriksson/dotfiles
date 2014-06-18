#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

readonly PROGDIR=$(cd "$(dirname "$0")" && pwd)
readonly PLATFORM=$(uname)

readonly HOMEBREW_URL="https://raw.github.com/Homebrew/homebrew/go/install"
readonly OH_MY_ZSH_URL="https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh"
readonly CURL_FLAGS="-fsSL"

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
    link_file "${PROGDIR}/gitignore_global" "${HOME}/.gitignore_global"
    link_file "${PROGDIR}/gitconfig" "${HOME}/.gitconfig"
}

setup_vim() {
    command_exists vim || install_command vim
    link_file "${PROGDIR}/vim/vimrc" "${HOME}/.vimrc"
    link_file "${PROGDIR}/vim/Vundle.vim" "${HOME}/.vim/bundle/Vundle.vim"
    mkdir -p "${HOME}/.vim/undodir"
    vim +PluginInstall +qall
}

setup_zsh() {
    command_exists zsh || install_command zsh
    link_file "${PROGDIR}/zsh/oh-my-zsh" "${HOME}/.oh-my-zsh"
    link_file "${PROGDIR}/zsh/themes" "${PROGDIR}/zsh/oh-my-zsh/custom/themes"
    link_file "${PROGDIR}/zsh/zshrc" "${HOME}/.zshrc"
    link_file "${PROGDIR}/profile" "${HOME}/.profile"
    link_file "${PROGDIR}/aliases" "${HOME}/.aliases"
}

setup_git
setup_vim
setup_zsh
