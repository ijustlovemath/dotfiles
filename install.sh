#!/bin/bash

for i in "$@"; do
    case $i in
        -q|--quiet)
        SHH="1"
        ;;
    esac
done

shut_up () {
    if [[ -z "$SHH" ]]; then
        echo "bein loud"
        exec 3>&1 4>&2 
    else
        echo "shuttin up"
        exec 3>&1 4>&2 &>/dev/null
    fi
}

echo_always () {
    echo "$@" >&3
}

we_have () {
    type "$@" >/dev/null 2>&1
}

create_directory () {
	/bin/mkdir -p "$@" 2>&4
}

setup_directories () {
	echo_always "Setting up familiar directory structure..."
	create_directory "$PROJECT_DIR"
	create_directory "$DOCS_DIR"
}

get_packages () {
    sudo apt-get install -y "$@" 2>&4
}

update_system () {
    echo_always "Updating system..."
    sudo apt-get update && sudo apt-get upgrade 2>&4
}

add_configure_vim () {
    if [ -f ~/.vimrc ]; then
        echo_always "vim already installed, skipping"
        return
    fi
    echo_always "setting up ~the superior editor~ ..."
	get_packages vim
	echo "syntax on" > ~/.vimrc
	echo "set ts=4 sw=4 expandtab smarttab smartindent" >> ~/.vimrc
	echo "set number" >> ~/.vimrc
	echo "colo darkblue" >> ~/.vimrc
}

add_configure_zsh () {
    if [ -f "$HOME/.zshrc" ]; then
        echo_always "zsh already setup, skipping..."
        return
    fi
    echo_always "Installing and configuring zsh..."
    if [ ! we_have zsh ]; then
        get_packages zsh # TODO: oh-my-zsh
    fi
    #/usr/bin/chsh -s $(which zsh) "$USER"
    OLD_SHH="$SHH"
    unset SHH
    shut_up
    /bin/sh -c "$(/usr/bin/wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
    if [[ ! -z "$OLD_SHH" ]]; then
        SHH="$OLD_SHH"
    fi
    shut_up
    echo "ZSH_THEME=\"jtriley\"" >> ~/.zshrc
# TODO: add cd function
# TODO: add fsl alias

}

add_configure_git () {
    get_packages git
    git config --global user.email "jcdejournett@gmail.com"
    git config --global user.name "Jeremy DeJournett"
}

add_configure_ssh () {
    get_packages openssh-server
# TODO: generate private key for this machine
}

add_configure_python () {
    if we_have pip3; then
        echo "Python installed, skipping..."
        return
    fi
    echo "Setting up python and pip..." >&3
    get_packages python-pip python3-pip python3-dev python3-setuptools
}

add_configure_fuck () {
    if we_have thefuck; then
        echo_always "fuck installed, skipping..."
    fi
    sudo pip3 install thefuck
    echo "eval \$(thefuck --alias)" >> ~/.zshrc
}

add_configure_cdh () {
    CDH_REPO="$PROJECT_DIR/LAICE_CDH"
    if [ -d "$CDH_REPO" ]; then
        echo_always "C&DH repo already installed at: $CDH_REPO"
        return
    fi
    echo_always "Adding C&DH repo..."
	get_packages cmake
	get_packages cmake-curses-gui
	get_packages libssl-dev
	git clone https://gitlab.engr.illinois.edu/cubesat/LAICE_CDH.git "$CDH_REPO" 2>&4
    create_directory "$CDH_REPO/native"
}

if [[ -z "$PROJECT_DIR" ]]; then
	PROJECT_DIR="$HOME/projects"
fi

if [[ -z "$DOCS_DIR" ]]; then
	DOCS_DIR="$HOME/doc"
fi

shut_up
update_system
setup_directories
add_configure_git
add_configure_python
add_configure_zsh
add_configure_vim
add_configure_fuck
get_packages tmux
get_packages build-essential

if [[ ! -z "$ADD_CDH" ]]; then
    add_configure_cdh
fi
