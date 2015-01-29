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

readonly VIM_PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
readonly HOMEBREW_URL="https://raw.githubusercontent.com/Homebrew/install/master/install"

colorize() {
    local color=$1
    local msg=$2
    echo "$(tput setaf ${color})${msg}$(tput sgr 0)"
}

log() {
    colorize 4 "$1"
}

fail() {
    colorize 1 "ERROR: $1"; exit 1
}

log_header() {
    log "*****${1}*****"
}

is_cmd() {
    hash "$1" 2> /dev/null && return 0 || return 1
}

add_link() {
    local source=$1
    local target=$2

    if [[ ! -L "$target" || $(readlink "$target") != "$source" ]]; then
        log "Linking ${source} to ${target}."
        ln -sni "$source" "$target"
    fi
}

download() {
    local from=$1
    if [ -z $2 ]; then
        log "Downloading $from."
        curl -fsSL "$from"
    else
        local to=$2
        if [ ! -f "$to" ]; then
            log "Downloading ${from} to ${to}."
            curl -fsSLo "$to" "$from"
        fi
    fi
}

make_dir() {
    [ -d "$1" ] || (log "Creating directory $1."; mkdir -p $1 2> /dev/null)
}

install_cmd() {
    local cmd=$1
    log "Attempting to install ${cmd}."

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

set_login_shell() {
    desired=$1

    if [[ "$PLATFORM" == "Darwin" ]]; then
        current=$(dscl . -read /Users/$(whoami) UserShell | cut -d' ' -f2)
    elif [[ "$PLATFORM" == "Linux" ]]; then
        current=$(getent passwd $LOGNAME | cut -d: -f7)
    fi

    if [[ "$current" != "$desired" ]]; then
        log "Changing login shell from ${current} to ${desired}."
        chsh -s "$desired"
    fi
}

setup_homebrew() {
    log_header "Setting up homebrew"

    is_cmd brew || ruby -e "$(download ${HOMEBREW_URL})"
    brew update
    brew list brew-cask > /dev/null 2>&1 || brew install caskroom/cask/brew-cask
    brew doctor
}

setup_git() {
    log_header "Setting up git"

    add_link "${GITDIR}/gitignore_global" "${HOME}/.gitignore_global"
    add_link "${GITDIR}/gitconfig" "${HOME}/.gitconfig"
}

setup_vim() {
    log_header "Setting up vim"

    is_cmd vim || install_cmd vim
    make_dir "${HOME}/.vim/undodir"
    make_dir "${HOME}/.vim/autoload"
    download "$VIM_PLUG_URL" "${HOME}/.vim/autoload/plug.vim"

    add_link "${VIMDIR}/vimrc" "${HOME}/.vimrc"
    vim +PlugInstall +qall
}

setup_zsh() {
    log_header "Setting up zsh"

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

    set_login_shell $(which zsh)
}

setup_tmux() {
    log_header "Setting up tmux"

    if [[ "$PLATFORM" == "Darwin" ]]; then
        is_cmd reattach-to-user-namespace || install_cmd reattach-to-user-namespace
        add_link "${TMUXDIR}/tmux.osx.conf" "${HOME}/.tmux.platform.conf"
    fi
    add_link "${TMUXDIR}/tmux.conf" "${HOME}/.tmux.conf"
}

setup_git
[[ "$PLATFORM" == "Darwin" ]] && setup_homebrew
setup_vim
setup_zsh
setup_tmux
