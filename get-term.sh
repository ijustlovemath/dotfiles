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

require wmctrl
require lsof
require xdotool

terminal_to_run="$1"
[ -z "$terminal_to_run" ] && die "need to tell me which terminal to run (first argument is path to terminal)"

# -l: list all windows that are visible
# -p: include process ID
window_info=("${(@f)$(wmctrl -l -p)}")

window_ids="$(echo -n  $window_info | awk '{print $1}')"
desktop_numbers="$(echo -n  $window_info | awk '{print $2}')"
process_ids="$(echo -n  $window_info | awk '{print $3}')"

focused_window="$(printf '0x%08x' $(xdotool getwindowfocus))"
echo $focused_window

terminal_windows=()

for info_block in "${window_info[@]}"
do
    pid="$(echo $info_block | awk '{print $3}')"
    exe="$(cat /proc/$pid/cmdline)"
    window="$(echo $info_block | awk '{print $1}')"
    if lsof -p $pid | grep "/dev/ptmx" >/dev/null 2>&1; then
        echo $exe, id $window is a terminal
        terminal_windows+=($window)
        if [[ "$window" -eq "$focused_window" ]]; then
            echo focused window is terminal
        fi

        if [[ "$window" -eq "$focused_window" && -e $terminal_to_run ]]; then
            echo and file
        fi
        if [[ "$window" -eq "$focused_window" && -e $terminal_to_run && "$(dirname $(readlink -f $terminal_to_run))" =~ "/usr/"*"bin" ]]; then
            echo $focused_window $window
            echo "would have run " $terminal_to_run
        fi
    fi
done

echo $terminal_windows

# for comparing output of /proc/XX/environ
# cmp -l file1.bin file2.bin | gawk '{printf "%08X %02X %02X\n", $1, strtonum(0$2), strtonum(0$3)}'
