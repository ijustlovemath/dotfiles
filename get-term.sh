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

spawn_terminal () {
    $terminal_to_run &
}

start="$(date +%s.%N)"

echo script started @ $start

# We need these commands installed to run
require wmctrl
require lsof
require xdotool
require bc # for timing, could use system python

# Check to make sure the terminal we're meant to spawn exists and is good
terminal_to_run="$1"
[ -z "$terminal_to_run" ] && die "need to tell me which terminal to run (first argument is path to terminal)"
verify_terminal_exists "$terminal_to_run" || die "the terminal you gave ($terminal_to_run) doesn't exist or isn't in the right place"

# wmctrl gives you actual visible windows, not just X objects!
# It gives the window ID and the process ID that is tied to that window,
# which is useful for figuring out if a terminal is running within that window
# -l: list all windows that are visible
# -p: include process ID
# We make it into an array so we can iterate over it without sed hackery
window_info=("${(@f)$(wmctrl -l -p)}")

# This is the window focused by the user at script execution
# Format the provided ID as hex for comparison with output of wmctrl
focused_window="$(printf '0x%08x' $(xdotool getwindowfocus))"

# Keep track of all windows that are terminals
terminal_windows=()

# All processes with a reference to /dev/ptmx
open_terminals="$(lsof -t /dev/ptmx)"

found=""

# Here's the plan!
# 1. Try and find an existing terminal; use that UNLESS the focused window is a terminal
#     - as a caveat, we will randomly pick from the list of found terminals
# 2. If no existing terminals found, spawn a new one

# Iterate over all windows found earlier
loop_start="$(date +%s.%N)"
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
    if echo $open_terminals | grep $pid >/dev/null 2>&1; then
        terminal_windows+=($window)

        # We found a terminal, so set a flag to prevent the fallback from spawning
        # Because we found a terminal, randomly pick from the set of terminals at the end
        found="1"


        # If the focused window is already a terminal, spawn a new one!
        if [[ "$window" -eq "$focused_window" ]]; then
            echo "would have run " $terminal_to_run
            echo "did this because focused window is already a terminal"
            echo "bailing out since our purpose is fulfilled"

            spawn_terminal
            # We bail out because if we don't, we need a complicated flag setup to enable the randomly picked shell 
            exit 0
        fi
    fi
done


loop_end="$(date +%s.%N)"

echo loop completed in $(echo $loop_end - $loop_start | bc -l)

# If we did not find a terminal window available, spawn a new one!
if [ -z "$found" ]; then
    echo "as a fallback, making a brand spankin new terminal"
    spawn_terminal
else 
    echo "randomly picking a terminal window..."
    while [ -z "$selected_terminal" ]; do
        selected_terminal=${terminal_windows[$RANDOM % ${#terminal_windows[@]} ]}
    done
    term_found_at="$(date +%s.%N)"
    echo "selected terminal window $selected_terminal"

    # timing how long the terminal took to find 
    echo found random term in $(echo $term_found_at - $loop_end | bc -l)

    # Focus the randomly selected window
    # -i means use the window ID as an argument
    # -a means focus the given window
    wmctrl -ia $selected_terminal
fi


# for comparing output of /proc/XX/environ
# cmp -l file1.bin file2.bin | gawk '{printf "%08X %02X %02X\n", $1, strtonum(0$2), strtonum(0$3)}'
