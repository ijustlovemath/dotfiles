#!/bin/bash

for i in "$@"; do
    case $i in
        -q|--quiet)
        SHH="1"
        ;;
    esac
done

if [[ -z "$SHH" ]]; then
    exec 3>&1 4>&2 
else
    exec 3>&1 4>&2 &>/dev/null
fi


create_directory () {
	/bin/mkdir -p "$@" 2>&4
}

setup_directories () {
	echo "Setting up familiar directory structure..." >&3
	create_directory "$PROJECT_DIR"
	create_directory "$DOCS_DIR"
}

get_packages () {
    sudo apt-get install -y "$@" 2>&4
}

update_system () {
    echo "Updating system..." >&3
    sudo apt-get update && sudo apt-get upgrade 2>&4
}

add_configure_vim () {
    echo "setting up ~the superior editor~ ..." >&3
	get_packages vim
	echo "syntax on" > ~/.vimrc
	echo "set ts=4 sw=4 expandtab smarttab smartindent" >> ~/.vimrc
	echo "set number" >> ~/.vimrc
	echo "colo darkblue" >> ~/.vimrc
}

add_configure_zsh () {
    echo "Installing and configuring zsh..." >&3
    get_packages zsh # TODO: oh-my-zsh
    /usr/bin/chsh -s $(which zsh) "$USER"
    /bin/sh -c "$(/usr/bin/wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
    echo "ZSH_THEME=\"jtriley\"" >> ~/.zshrc
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

add_configure_cdh () {
    echo "Adding C&DH repo..." >&3
    CDH_REPO="$PROJECT_DIR/LAICE_CDH"
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

update_system
setup_directories
add_configure_git
add_configure_vim
get_packages tmux
add_configure_zsh
get_packages build-essential

if [[ ! -z "$ADD_CDH" ]]; then
    add_configure_cdh
fi

