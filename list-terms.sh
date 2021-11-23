#!/usr/bin/env zsh
we_have () {
    type "$@" >/dev/null 2>&1
}

die () {
    echo "$@"
    exit 1
}

require () {
    if ! we_have $1; then
        die "need $1 to function"
    fi
}

verify_terminal_exists () {
# Check whether the terminal to run is actually a file, and lives somewhere in /usr/*/bin
# (aka it is legit and was installed by a package manager)
    [[ -e "$terminal_to_run" && "$(dirname $(readlink -f $terminal_to_run))" =~ "/usr/"*"bin" ]]

}

# We need these commands installed to run
require wmctrl
require lsof


# wmctrl gives you actual visible windows, not just X objects!
# It gives the window ID and the process ID that is tied to that window,
# which is useful for figuring out if a terminal is running within that window
# -l: list all windows that are visible
# -p: include process ID
# We make it into an array so we can iterate over it without sed hackery
window_info=("${(@f)$(wmctrl -l -p)}")

# Keep track of all windows that are terminals
terminal_windows=()

found=""

# Here's the plan!
# 1. Try and find an existing terminal; use that UNLESS the focused window is a terminal
#     - as a caveat, we will randomly pick from the list of found terminals
# 2. If no existing terminals found, spawn a new one

# Iterate over all windows found earlier
echo "PID\tWindow ID"
for info_block in "${window_info[@]}"
do
    # Process ID tied to the given window
    pid="$(echo $info_block | awk '{print $3}')"
    
    # (optional) Shell command used to spawn the process (eg /bin/bash)
    exe="$(cat /proc/$pid/cmdline)"

    # Window ID tied to the given window. Given as 0xHHHHHHHH (4 bytes in hex)
    window="$(echo $info_block | awk '{print $1}')"

    # To find terminals we use a little hack;
    # For every window, use lsof to look at that window's parent process
    # All terminals will (if they're well behaved) have an open file descriptor to
    # /dev/ptmx, which is the device file that gives you access to a terminal 
    # through the kernel
    
    # So we:
    # 1. look at all files opened by a given window's parent process
    # 2. look within those files for a reference to /dev/ptmx
    # 3. You got yourself a terminal! 
    if lsof -p $pid /dev/ptmx >> lsof.log; then
        terminal_windows+=($window)

        echo "$pid\t$window"

    fi
done
