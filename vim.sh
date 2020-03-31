# make the bundle directory
mkdir -p ~/.vim/bundle
# TODO: make variable for ~/.vim/bundle/Vundle.vim

# get vundle
 git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

# install vundle in vimrc
cat << EOF >> ~/.vimrc
set nocompatible
filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'ycm-core/YouCompleteMe'
call vundle#end()
filetype plugin indent on
EOF

# change .vim to unix using
find ~/.vim/bundle -type f -name "*.vim" -exec dos2unix {} \;

# execute PluginInstall
vim -c 'PluginInstall' -c 'qa'

#install c languages (or just all, lol)
python3 ~/.vim/bundle/YouCompleteMe/install.py --all
