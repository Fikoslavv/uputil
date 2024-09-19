#!/bin/bash

function set_settings_to_default()
{
    QUIET="1";
    VERBOSE="1";
    LAUNCH_DELAY="0";
    TERMINAL="konsole -e";
    HELP="1";
}

#Sets up variables based on passed short argumetns (e.g. -q)
function interpreteShortArguments()
{
    local letter;
    
    while [ "$#" -gt 0 ]; do

        for ((i = 1; i < ${#1}; i++)); do

            letter="${1:i:1}";

            [[ "$letter" == "q" ]] && QUIET="0";
            [[ "$letter" == "v" ]] && VERBOSE="0";

        done

        shift;

    done
}

#Sets up variables based on passed long arguments (e.g. --quiet)
function interpreteLongArguments()
{
    while [ "$#" -gt 0 ]; do

        [[ "$1" == "--quiet" ]] && QUIET="0"
        [[ "$1" == "--verbose" ]] && VERBOSE="0";
        [[ "$1" == "--help" ]] && HELP="0";
        grep -Eq "[-][-]delay=([0-9])|([1-9][0-9]+)" <<< "$1" && LAUNCH_DELAY="${1:8:${#1} - 8}";
        grep -Eq "[-][-]terminal-cmd=[a-zA-Z0-9_]+[-]+[a-zA-Z0-9_]+" <<< "$1" && TERMINAL="${1:15:${#1} - 15}";

        shift;

    done
}

#Sets up variables based on passed arguments
function interpreteArguments()
{
    while [ "$#" -gt 0 ]; do

        if [[ "${1:0:2}" == "--" ]]; then

            interpreteLongArguments "$1";

        elif [[ "${1:0:1}" == "-" ]]; then

            interpreteShortArguments "$1";

        fi

        shift;

    done
}

function get_is_verbose()
{
    [ "$VERBOSE" -eq 0 ] && return 0;
    return 1;
}

function get_is_quiet()
{
    [ "$QUIET" -eq 0 ] && return 0;
    return 1;
}

function get_is_help()
{
    [ "$HELP" -eq 0 ] && return 0;
    return 1;
}

set_settings_to_default;
interpreteArguments "$@";

if get_is_help; then

    printf "uputil-launcher [args]";

    printf "Possible args ↓\n";
    printf " --help => displays this message and quits\n";
    printf " -q --quiet => supresses messages and sets --no-interact\n";
    printf " -v --verbose => displays debug messages\n";
    printf " --delay=x => delays launch of uputil by amount of second x is equal to\n";
    printf " --terminal-cmd=<command> => sets terminal the uputil will be invoked in. The default is konsole. Terminal of choice has to be invokable in a way that allows to add command that would be executed. e.g. gnome-terminal --, konsole -e are both correct commands\n";

    exit 0;

fi

[ "$LAUNCH_DELAY" -gt 0 ] && sleep "$LAUNCH_DELAY";

command="uputil --no-interact -c";

get_is_quiet && command="$command""q";
get_is_verbose && command="$command""v";

$command && exit 0;

command="$TERMINAL uputil --upgrade --no-interact --interactable-exit";

get_is_quiet && command="$command --quiet";
get_is_verbose && command="$command --verbose";

$command;
exit "$?";
