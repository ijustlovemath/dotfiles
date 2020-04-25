#!/bin/bash

# TODO: enable all things using internally checked flags
# TODO: add --headless tag which automatically disables software thats used in a gui
# TODO: platform independent get_packages

for i in "$@"; do
    case $i in
        -q|--quiet)
        SHH="1"
        ;;
        --no-logout)
        [[ -z "$PROMPT_LOGOUT" ]] && PROMPT_LOGOUT="skip"
        ;;
        --logout)
        [[ -z "$PROMPT_LOGOUT" ]] && PROMPT_LOGOUT="logout"
        ;;
        --pianobar)
        ADD_PIANOBAR="1"
        ;;
        --cdh)
        ADD_CDH="1"
        ;;
        --all)
        ADD_CDH="1"
        ADD_PIANOBAR="1"
        ;;
        *)
        echo "unrecognized option: $i"
        ;;
    esac
done

shut_up () {
    if [[ -z "$SHH" ]]; then
        exec 3>&1 4>&2 
    else
        exec 3>&1 4>&2 &>/dev/null
    fi
}

echo_always () {
    #light purple
    ECHO_COLOR='\033[1;35m'
    NC='\033[0m'
    builtin echo -e "$ECHO_COLOR$@$NC" >&3
}

we_have () {
    type "$@" >/dev/null 2>&1
}

create_directory () {
	/bin/mkdir -p "$@" 2>&4
}

add_configure_sudo () {
    if we_have sudo; then
        return
    fi
    echo_always "Enter root password to install sudo:"
    su -c "apt-get install sudo" root
    if ! we_have sudo; then
        echo_always "[ERROR] sudo install failed, rest of process will fail"
    fi
    echo_always "Enter root password to add $USER to sudo group:"
    su -c "usermod -aG sudo $USER" root
    kill -9 -1
}

setup_directories () {
	echo_always "Setting up familiar directory structure..."
	create_directory "$PROJECT_DIR"
	create_directory "$DOCS_DIR"
}

die() {
    echo_always "[ERROR] $@"
    exit 1
}

get_package () {
    if we_have "$1"; then
        echo_always "[SKIP] we have $1 already"
        return
    fi
    if ! sudo apt-get install -y "$1" 2>&4; then
        die "could not find '$1' for install, bailing out"
    fi
}

get_packages () {
    IFS=" " read -ra PACKAGES <<< "$@"
    for package in "${PACKAGES[@]}"; do
        get_package "$package"
    done
}

update_system () {
    echo_always "Updating system..."
    sudo apt-get update && sudo apt-get upgrade 2>&4
}

add_configure_vim () {
    if [ -f ~/.vimrc ]; then
        echo_always "[SKIP] vim already setup"
        return
    fi
    echo_always "setting up ~the superior editor~ ..."
	get_packages vim
	echo "syntax on" > ~/.vimrc
	echo "set ts=4 sw=4 expandtab smarttab smartindent" >> ~/.vimrc
	echo "set number" >> ~/.vimrc
	echo "colo darkblue" >> ~/.vimrc
}
get_ohmyzsh() {
    echo_always "Installing oh-my-zsh (enter password)"
    export RUNZSH=no
    export CHSH=no
    OHMYZSH_SCRIPT="/tmp/ohmyzsh.install.sh"
    if ! /usr/bin/wget "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" -O "${OHMYZSH_SCRIPT}"; then
        die "oh-my-zsh failed to download"
    fi
    if ! chmod +x "${OHMYZSH_SCRIPT}"; then
        die "cant execute oh-my-zsh script"
    fi
    if ! /bin/sh "${OHMYZSH_SCRIPT}"; then
        die "oh-my-zsh failed to install"
    fi
}

add_configure_zsh () {
    if [ -f "$ZSHRC" ]; then
        echo_always "[SKIP] zsh already setup"
        return
    fi
    echo_always "Installing and configuring zsh..."
    if ! we_have zsh; then
        get_packages zsh 
    fi
#    OLD_SHH="$SHH"
#    OLD_SHELL="$SHELL"
#    unset SHH
#    shut_up
#    SHELL=$(which zsh) 
    get_ohmyzsh
#    if [[ ! -z "$OLD_SHH" ]]; then
#        SHH="$OLD_SHH"
#    fi
#    shut_up
#    SHELL="$OLD_SHELL"

    echo_always "Setting zsh as default shell for $USER, enter password"
    chsh -s $(which zsh) $USER

    echo_always "Setting theme to jtriley"
    sed -i 's/^ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"jtriley\"/' $ZSHRC
#    sed -i '/^ZSH_THEME=*/d' $ZSHRC
#    echo "ZSH_THEME=\"jtriley\"" >> $ZSHRC

    #https://stackoverflow.com/a/15965681
#    if ! sed -i '/ZSH_THEME=/!{q100}; {s/ZSH_THEME=*/ZSH_THEME=jtriley/}' $ZSHRC; then
#        echo "ZSH_THEME=\"jtriley\"" >> $ZSHRC
#    fi
    if ! grep "cd () {" $ZSHRC >/dev/null 2>&1; then
    cat >> $ZSHRC << EOL
cd () {
    builtin cd "\$@" && ls -F
}
EOL
    fi

    if ! grep "alias fsl=" $ZSHRC >/dev/null 2>&1; then
    cat >> $ZSHRC << EOL
alias fsl='kill -9 -1'
EOL
    fi

}

add_configure_git () {
    get_packages git
    if we_have git && [[ ! -z "$(git config --global user.email)" ]]; then
        echo_always "[SKIP] Git email already set, skipping autoconfig"
        return
    fi
    if we_have git && [[ ! -z "$(git config --global user.name)" ]]; then
        echo_always "[SKIP] Git full name already set, skipping autoconfig"
        return
    fi
    if [[ -z "$EMAIL" ]]; then
        echo_always "Git autoconfig failed, please provide an EMAIL= variable"
        return
    fi
    if [[ -z "$NAME" ]]; then
        echo_always "Git autoconfig failed, please provide a NAME= variable"
        return
    fi
    git config --global user.email "$EMAIL"
    git config --global user.name "$NAME"

    if ! we_have xclip; then
        get_packages xclip
    fi
    if ! cat "$HOME/.ssh/id_rsa.pub" | xclip -selection clipboard; then
        echo_always "[INFO] unable to copy public ssh key to clipboard, skipping git registration"
        return
    fi

    echo_always "[INFO] Copied ~/.ssh/id_rsa.pub to clipboard, register here:"
    echo_always "[INFO] https://github.com/settings/ssh/new"
    echo_always "[INFO] https://gitlab.com/profile/keys"
    echo_always "[INFO] Attempting to open browser for you..."
    xdg-open "https://gitlab.com/profile/keys" &
    xdg-open "https://github.com/settings/ssh/new" &
}

add_configure_ssh () {
    get_packages openssh-server

    if [[ -z "$EMAIL" ]]; then
        echo_always "[WARNING] not generating SSH key for this machine, define $EMAIL to do this automatically"
        return
    fi

    if [ ! -d "$HOME/.ssh" ]; then
        create_directory "$HOME/.ssh"
    fi

    if [ -f "$HOME/.ssh/id_rsa" ]; then
        echo_always "[INFO] SSH key already exists, using that one"
        return
    fi
    if ! ssh-keygen -b 4096 -f "$HOME/.ssh/id_rsa" -t rsa -C "$EMAIL"; then
        die "ssh-keygen failed"
    fi
}

add_configure_python () {
    if we_have pip3; then
        echo "[SKIP] Python already installed"
        return
    fi
    echo "Setting up python and pip..." >&3
    get_packages python-pip-whl python3-pip python3-dev python3-setuptools
}

add_configure_fuck () {
    if we_have thefuck; then
        echo_always "[SKIP] thefuck installed"
    else
        sudo pip3 install thefuck
    fi
    THEFUCK_EVAL_STR="eval \$(thefuck --alias --enable-experimental-instant-mode)"
    if ! grep "$THEFUCK_EVAL_STR" $ZSHRC >/dev/null 2>&1; then
        echo $THEFUCK_EVAL_STR >> $ZSHRC
    else
        echo_always "[SKIP] thefuck alias already in zshrc"
    fi
}

add_configure_control_pianobar () {

    if ! we_have git; then
        echo_always "[ERROR] git required to get control-pianobar"
        return
    fi

    if we_have control-pianobar; then
        echo_always "[SKIP] control-pianobar already installed"
        return
    fi

    if we_have pianobar-notify; then
        echo_always "[SKIP] pianobar-notify already installed"
        return
    fi

    CLONE_DIR="$(mktemp -d -p /tmp)"
    if [[ -z "$CLONE_DIR" ]]; then
        echo_always "[ERROR] Unable to get control-pianobar, tempdir failed"
        return
    fi

    git clone https://github.com/Malabarba/control-pianobar $CLONE_DIR
    pushd $CLONE_DIR
    git reset --hard 9bd17c

    if [[ -z "$PIANOBAR_INSTALL_DIR" ]]; then
        PIANOBAR_INSTALL_DIR="$(dirname $(which pianobar))"
    fi

    sudo cp control-pianobar.sh "$PIANOBAR_INSTALL_DIR"/control-pianobar
    sudo cp pianobar-notify.sh "$PIANOBAR_INSTALL_DIR"/pianobar-notify
    popd
    echo_always "Installed control-pianobar scripts to $PIANOBAR_INSTALL_DIR"

    if ! rm -rf "$CLONE_DIR"; then
        echo_always "Unable to clean up control-pianobar clone directory, it's here: $CLONE_DIR"
    fi

    # If the pianobar config file location is defined, attempt to add an event_command config
    [[ -z "$PIANOBAR_CFG_FILE" ]] && return

    if grep event_command $PIANOBAR_CFG_FILE >/dev/null 2>&1; then
        echo_always "[WARNING] event_command already defined in pianobar config file"
        return
    fi
    cat >> $PIANOBAR_CFG_FILE <<EOL
event_command = $PIANOBAR_INSTALL_DIR/pianobar-notify
EOL

}

add_configure_pianobar () {
    if we_have pianobar; then
        echo_always "[SKIP] pianobar installed"
        return
    fi

    get_packages pianobar

    if [[ -z "$PIANOBAR_CFG_DIR" ]]; then
        PIANOBAR_CFG_DIR="$HOME/.config/pianobar"
    fi

    create_directory $PIANOBAR_CFG_DIR
    PIANOBAR_CFG_FILE="$PIANOBAR_CFG_DIR/config"

    if [[ -z "$PIANOBAR_EMAIL" ]]; then
        PIANOBAR_EMAIL="$EMAIL"
    fi

    # TODO: don't overwrite config if it exists
    if [[ ! -z "$PIANOBAR_EMAIL" ]]; then
        cat >$PIANOBAR_CFG_FILE <<EOL
user = $PIANOBAR_EMAIL
EOL
        echo_always "pianobar config has an email, you may want to add a \"password = xx\" option" 

    else    
        echo_always "[WARNING] PIANOBAR_EMAIL not set, EMAIL not set, pianobar autoconfig failed"
    fi

    # Now try and get control-pianobar setup
    add_configure_control_pianobar

    if ! we_have xbindkeys; then
        get_packages xbindkeys
    fi

    if [[ -z "$XBINDKEYS_CFG_FILE" ]]; then
        XBINDKEYS_CFG_FILE="$HOME/.xbindkeysrc"
    fi

    if grep control-pianobar "$XBINDKEYS_CFG_FILE" >/dev/null 2>&1; then
        echo_always "[SKIP] xbindkeys already has bindings for control-pianobar"
        return
    fi

    cat >> $XBINDKEYS_CFG_FILE <<EOL
"control-pianobar p"
    Alt + Down
"control-pianobar d"
    Alt + D
"control-pianobar n"
    Alt + Right
"control-pianobar switchstation"
    Alt + S
"control-pianobar love"
    Alt + Up
EOL

}

cleanup () {
    case "$PROMPT_LOGOUT" in
        "skip")
        DO_LOG="No"
        ;;
        "logout")
        DO_LOG="Yes"
        ;;
    esac
    if [[ -z "$DO_LOG" ]]; then
        echo_always "to make zsh take effect, you need to logout, would you like to? "
        read DO_LOG
    fi
    if [[ "$DO_LOG" =~ y|Y|yes|Yes|YES|sure|ya|ok ]]; then
        kill -9 -1
    fi
    echo_always "Congrats on the install!"
}

add_configure_repo() {
    # Usage: add_configure repo git@github.com:a/b src "dep1 dep2" native

    # git location (required)
    REPO_LOCATION="$1"

    # subdirectory to look for to see if it's already installed (required)
    REPO_EXISTS_DIR="$2"

    # packages needed (optional)
    PKG_DEPENDENCIES="$3"

    # if relative, use $PROJECT_DIR as parent (optional, default: basename $REPO_LOCATION)
    #REPO_DESTINATION="$4"

    # CMake build directory name (optional, default: 'native')
    CMAKE_BUILD_DIR="$4"

    if [[ -z "$REPO_LOCATION" ]] || [[ -z "REPO_EXISTS_DIR" ]]; then
        die "need at least two arguments to $0"
    fi

    local REPO_NAME="$(basename -- $REPO_LOCATION)"
    local BASE_REPO_NAME="${REPO_NAME%.*}"
    REPO_DESTINATION="$PROJECT_DIR/$BASE_REPO_NAME"

    if [[ -z "$REPO_DESTINATION" ]]; then
        die "problem processing repo name: $REPO_LOCATION, $REPO_NAME, $REPO_DESTINATION"
    fi

    if [ -d "$REPO_DESTINATION/$REPO_EXISTS_DIR" ]; then
        echo_always "[SKIP] $BASE_REPO_NAME repo already exists"
        return
    fi

    # go ahead with the install
    if [[ ! -z "$PKG_DEPENDENCIES" ]]; then
        # loop through all dependencies, space-separated
        # install them if  we dont have them
        get_packages "$PKG_DEPENDENCIES"
    fi

    if ! git clone "$REPO_LOCATION" "$REPO_DESTINATION" 2>&4; then
        die "unable to close $BASE_REPO_NAME"
    fi

    if [[ ! -z "$CMAKE_BUILD_DIR" ]]; then
        create_directory "$REPO_DESTINATION/$CMAKE_BUILD_DIR"
    fi
}

add_configure_imt () {
    add_configure_repo git@gitlab.com:dejournett/imt-c-controller lib "cmake cmake-curses-gui doxygen" native
}

add_configure_cdh () {
    if ! we_have git; then
        echo_always "[ERROR] git required to clone LAICE_CDH repo"
        return
    fi

    CDH_REPO="$PROJECT_DIR/LAICE_CDH"

    if [ -d "$CDH_REPO/src" ]; then
        echo_always "[SKIP] C&DH repo already installed at: $CDH_REPO"
        return
    fi

    echo_always "Adding C&DH repo..."
	get_packages cmake cmake-curses-gui libssl-dev
    echo_always "Cloning C&DH repo to $CDH_REPO..."
	git clone https://gitlab.engr.illinois.edu/cubesat/LAICE_CDH.git "$CDH_REPO" 2>&4
    create_directory "$CDH_REPO/native"
}

if [[ -z "$PROJECT_DIR" ]]; then
	PROJECT_DIR="$HOME/projects"
fi

if [[ -z "$DOCS_DIR" ]]; then
	DOCS_DIR="$HOME/doc"
fi

if [[ -z "$ZSHRC" ]]; then
    ZSHRC="$HOME/.zshrc"
fi

shut_up
add_configure_sudo
update_system
setup_directories
add_configure_ssh
add_configure_git
add_configure_python
add_configure_zsh
add_configure_vim
add_configure_fuck
get_packages tmux
get_packages build-essential

add_configure_imt

if [[ ! -z "$ADD_CDH" ]]; then
    add_configure_cdh
fi

if [[ ! -z "$ADD_PIANOBAR" ]]; then
    add_configure_pianobar
fi

cleanup
