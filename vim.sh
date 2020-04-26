#!/bin/bash

die () {
    echo "[ERROR] $@"
    exit 1
}
# make the bundle directory
BUNDLE_DIR="$HOME/.vim/bundle"
mkdir -p "$BUNDLE_DIR"

# get vundle (continue if we have it)
if [ ! -d "$BUNDLE_DIR/Vundle.vim" ]; then
    git clone https://github.com/VundleVim/Vundle.vim.git "$BUNDLE_DIR/Vundle.vim"
fi

# install vundle in vimrc (if it doesnt exist already)
if ! grep "vundle" "$HOME/.vimrc"; then
    cat << EOF >> "$HOME/.vimrc"
set nocompatible
filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'ycm-core/YouCompleteMe'
call vundle#end()
filetype plugin indent on
EOF
else
    echo "we already have vundle in vimrc"
fi

# change .vim to unix using (always do this)
find "$BUNDLE_DIR" -type f -name "*.vim" -exec dos2unix {} \;

# execute PluginInstall (nop if its done already)
if ! vim -s "add_vundle.vim"; then
    die "adding vundle failed"
fi

#install c languages, use ninja
python3 "$BUNDLE_DIR/YouCompleteMe/install.py" --clang-completer --ninja
