#!/bin/bash

if [[ "$1" == "--check-for-update" ]]; then

    command="dnf check-update -q";

    echo "[INFO] Triggering \"$command\"...";

    if ! $command > /dev/null; then

        printf "[INFO] There is an update available through dnf\n\n";
        exit 0;

    else

        printf "[INFO] No updates are available through dnf\n\n";
        exit 1;

    fi

elif [[ "$1" == "--upgrade" ]]; then

    command="sudo dnf update";

    printf "[INFO] Triggering %s...\n\n" "$command";

    $command;
    result=$?;

    if [ "$result" -eq 0 ]; then

        printf "\n[INFO] Update succeeded. Dnf returned code %s\n\n" "$result";
        exit 0;

    else

        printf "\n[WARN] Dnf returned code %s\n\n" "$result";
        exit "$result";

    fi

fi