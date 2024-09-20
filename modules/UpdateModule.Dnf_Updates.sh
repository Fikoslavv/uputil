#!/bin/bash

[ "$QUIET" ] || QUIET="1";
[ "$VERBOSE" ] || VERBOSE="0";

function get_is_quiet()
{
    [ "$QUIET" -eq 0 ] && return 0;
    return 1;
}

function get_is_verbose()
{
    [ "$VERBOSE" -eq 0 ] && return 0;
    return 1;
}

if [[ "$1" == "--check-for-update" ]]; then

    command="dnf check-update -q";

    if get_is_quiet || ! get_is_verbose; then
        $command --assumeno > /dev/null 2> /dev/null;
        result="$?";
    else
        $command;
        result="$?";
    fi

    if [ "$result" -eq 100 ]; then

        get_is_verbose && printf "[INFO] There is an update available through dnf\n\n";
        exit 0;

    elif [ "$result" -eq 0 ]; then

        get_is_verbose && printf "[INFO] No updates are available through dnf\n\n";
        exit 1;

    else

        get_is_verbose && printf "[ERR] Dnf returned code \"%s\"" "$result";
        exit "$result";

    fi

elif [[ "$1" == "--upgrade" ]]; then

    command="sudo dnf update";

    if get_is_quiet; then command="$command -y"; fi

    get_is_verbose && printf "[INFO] Triggering %s...\n\n" "$command";

    $command;
    result=$?;

    if [ "$result" -eq 0 ]; then

        get_is_verbose && printf "\n[INFO] Update succeeded. Dnf returned code %s\n\n" "$result";
        exit 0;

    else

        get_is_verbose && printf "\n[WARN] Dnf returned code %s\n\n" "$result";
        exit "$result";

    fi

fi