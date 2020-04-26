#!/bin/bash

# Allow the user to specify where to find these things
if [[ -z "$VIM_CONFIG_DIR" ]]; then
    VIM_CONFIG_DIR="$HOME/.vim"
fi

if [[ -z "$VIMRC_PATH" ]]; then
    VIMRC_PATH="$HOME/.vimrc"
fi

die () {
    echo "[ERROR] $@"
    exit 1
}

#requires: git, dos2unix, python3, vim
we_have () {
    type "$@" >/dev/null 2>&1
}

needs () {
    IFS=" " read -ra PACKAGES <<< "$@"
    for package in "${PACKAGES[@]}"; do
        if ! we_have $package; then
            die "we need $package to continue, get it from your package manager"
        fi
    done
}

# Make sure we have everything we need
needs "git dos2unix python3 vim"

# make the bundle directory
BUNDLE_DIR="$VIM_CONFIG_DIR/bundle"
mkdir -p "$BUNDLE_DIR"

# get vundle (continue if we have it)
if [ ! -d "$BUNDLE_DIR/Vundle.vim" ]; then
    git clone https://github.com/VundleVim/Vundle.vim.git "$BUNDLE_DIR/Vundle.vim"
fi

# install vundle in vimrc (if it doesnt exist already)
if ! grep "vundle" "$VIMRC_PATH" >/dev/null 2>&1; then
    cat << EOF >> "$VIMRC_PATH"
set nocompatible
filetype off

set rtp+=$BUNDLE_DIR/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'ycm-core/YouCompleteMe'
call vundle#end()
filetype plugin indent on
EOF
fi

# change .vim to unix using dos2unix, otherwise there might be issues (always do this)
find "$BUNDLE_DIR" -type f -name "*.vim" -exec dos2unix {} >/dev/null 2>&1 \;

# execute PluginInstall (nop if its done already)
if ! vim -s <(echo ":PluginInstall"; echo ":qa!"); then
    die "adding vundle failed"
fi

#install languages, use cmake. All argments from this script get passed to YCM installer
python3 "$BUNDLE_DIR/YouCompleteMe/install.py" $@
