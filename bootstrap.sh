#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

cd $(dirname ${BASH_SOURCE[0]})

readonly PROGDIR=$(cd "$(dirname "$0")" && pwd)
readonly ZSHDIR="${PROGDIR}/zsh"
readonly VIMDIR="${PROGDIR}/vim"
readonly GITDIR="${PROGDIR}/git"
readonly TMUXDIR="${PROGDIR}/tmux"
readonly PLATFORM=$(uname)
readonly DISTRO=$([[ "$PLATFORM" != "" ]] && lsb_release -a 2>/dev/null | grep Des | sed 's/Des.*:\s*//')

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

brew_has() {
    brew list "$1" > /dev/null 2>&1 && return 0 || return 1
}

cask_has() {
    brew cask list "$1" > /dev/null 2>&1 && return 0 || return 1
}

find_pip() {
    [[ ${PIP_CMD:-""} != "" ]]; PIP_CMD=$(which pip3 || which pip)
}

pip_has() {
    find_pip
    "$PIP_CMD" show "$1" > /dev/null 2>&1 && return 0 || return 1
}

install() {
    local cmd=$1
    if [[ "$PLATFORM" == "Darwin" ]]; then
        if ! brew_has "$cmd"; then
            log "Installing ${cmd}."
            brew install "$cmd"
        fi
    elif [[ "$PLATFORM" == "Linux" ]]; then
        if is_cmd yum; then
            log "Attempting to install ${cmd}."
            sudo yum install "$cmd"
        elif is_cmd apt-get; then
            log "Attempting to install ${cmd}."
            sudo apt-get install "$cmd"
        else
            fail "Unknown package manager"
        fi
    else
        fail "Unknown OS."
    fi
}

prompt() {
    while true; do
        read -p "$1?[yn] " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Answer yes or no.";;
        esac
    done
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

optional_brew_install() {
    local ys=""
    for pkg; do
        if (! brew_has "$pkg") && prompt "Install ${pkg}"; then
            ys="${ys} ${pkg}"
        fi
    done
    [ -z "$ys" ] || brew install $ys
}

optional_cask_install() {
    local ys=""
    for pkg; do
        if (! cask_has "$pkg") && prompt "Install ${pkg}"; then
            ys="${ys} ${pkg}"
        fi
    done
    [ -z "$ys" ] || brew cask install $ys
}

pip_upgrade() {
    find_pip
    for pkg; do
        "$PIP_CMD" install --upgrade -q $pkg 2>&1 || grep -v "Requirement already up-to-date"
    done
}

init_repo() {
    git submodule init
    git submodule update
}

setup_osx() {
    log_header "Setting up osx"

    log "Installing brew..."
    is_cmd brew || ruby -e "$(download ${HOMEBREW_URL})"
    log "Updating brew..."
    brew update | grep -v "Already up-to-date." || true
    log "Upgrading brew..."
    brew upgrade
    log "Running brew doctor..."
    brew doctor || true > /dev/null

    log "Cleaning up brew..."
    brew cleanup
}

setup_git() {
    log_header "Setting up git"

    add_link "${GITDIR}/gitignore_global" "${HOME}/.gitignore_global"
    add_link "${GITDIR}/gitconfig" "${HOME}/.gitconfig"
}

setup_vim() {
    log_header "Setting up vim"

    if [[ "$DISTRO" == "Ubuntu*" ]]; then
        if $(grep -R neovim-ppa /etc/apt/sources.* >/dev/null 2>&1); then
            # Add repository for neovim
            install python-software-properties
            sudo add-apt-repository ppa:neovim-ppa/stable
            sudo apt-get update
        fi
    fi

    is_cmd nvim || install neovim
    make_dir "${HOME}/.vim/undodir"
    make_dir "${HOME}/.vim/autoload"
    make_dir "${HOME}/.local/share/nvim/site/autoload"
    download "$VIM_PLUG_URL" "${HOME}/.vim/autoload/plug.vim"
    download "$VIM_PLUG_URL" "${HOME}/.local/share/nvim/site/autoload/plug.vim"

    add_link "${VIMDIR}/vimrc" "${HOME}/.vimrc"
    mkdir -p "${HOME}/.config/nvim" 2>/dev/null
    add_link "${HOME}/.vimrc" "${HOME}/.config/nvim/init.vim"

    vim +PlugUpgrade +qall
    vim +PlugUpdate +qall
}

setup_zsh() {
    log_header "Setting up zsh"

    is_cmd zsh || install zsh
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

setup_fonts() {
    log "Setting up powerline fonts"
    ./fonts/install.sh
}

setup_python() {
    log_header "Setting up Python"

    pip_upgrade setuptools distribute pip
}

setup_packages() {
    log_header "Adding optional packages"

    if [[ "$PLATFORM" == "Darwin" ]]; then
        log "Adding brew packages..."
        optional_brew_install \
            awscli \
            clojure \
            clj-kondo \
            coreutils \
            fswatch \
            fzf \
            git \
            glances \
            httpie \
            irssi \
            jq \
            kubernetes-cli \
            helm \
            k9s \
            leiningen \
            neovim \
            node \
            pgcli \
            python3 \
            ripgrep \
            starship \
            tmux \
            tree \
            vim \
            wget
    fi
}

setup_tmux() {
    log_header "Setting up tmux"

    if [[ "$PLATFORM" == "Darwin" ]]; then
        install reattach-to-user-namespace
        add_link "${TMUXDIR}/tmux.osx.conf" "${HOME}/.tmux.platform.conf"
    fi
    add_link "${TMUXDIR}/tmux.conf" "${HOME}/.tmux.conf"
}

init_repo
setup_git
setup_vim
setup_zsh
setup_tmux
[[ "$PLATFORM" == "Darwin" ]] && setup_osx
setup_packages
setup_python
