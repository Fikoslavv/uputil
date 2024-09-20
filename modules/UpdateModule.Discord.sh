#!/bin/bash

[ "$QUIET" ] || QUIET="1";
[ "$VERBOSE" ] || VERBOSE="0";

#Prefix[$1].randomHex"$2"DigitNumber.Suffix[$3] (Dots indcluded)
function generateFileName()
{
    fileName="$1.$(openssl rand -hex "$2").$3";
    while [ -f "$fileName" ]; do
        fileName="$1.$(openssl rand -hex "$2").$3";
    done

    echo "$fileName";
}

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

function print()
{
    ! get_is_quiet && get_is_verbose && printf "%s" "$*";
}

function println()
{
    ! get_is_quiet && get_is_verbose && printf "%s\n" "$*";
}

installDir="/usr/lib64/discord";

if [[ "$1" == "--check-for-update" ]]; then
    println "[INFO] Running update check for discord";

    if ! cd "/tmp"; then
        println "[ERR] Failed to change working directory to \"/tmp\"!" > /dev/stderr;
        exit 2;
    fi

    redirectSite="$(generateFileName "discord.redirect" "30" "html")";

    if ! curl -so "$redirectSite" "https://discord.com/api/download?platform=linux&format=tar.gz"; then
        println "[ERR] Failed to download redirect site from \"https://discord.com/api/download?platform=linux&format=tar.gz\".";

        if [ -f "$redirectSite" ]; then
            if rm "$redirectSite"; then
                println "[INFO] Successfully removed temp file \"$redirectSite\".";
                exit 3;
            else
                println "[ERR] Failed to remove temp file \"$redirectSite\"!" > /dev/stderr;
                exit 4;
            fi
        else
            println "[WARN] Temp file \"$redirectSite\" doesn't exist in \"$PWD\" directory!" > /dev/stderr;
            exit 5;
        fi
    fi

    # if [ -f /lib64/discord/resources/build_info.json ]; then
    if [ -f "$installDir/resources/build_info.json" ]; then
        installedVersion="$(cat $installDir/resources/build_info.json | grep -Eo "([0-9]*[.])*[0-9]+")";
    else
        installedVersion="null";
    fi

    println "[INFO] Installed version of discord is \"$installedVersion\".";

    newestVersion="$(grep -Eo "([0-9]*[.])*[0-9]+" <<< cat "$PWD/$redirectSite" | tail -n 1)";

    if [ -f "$redirectSite" ]; then
        if rm "$redirectSite"; then
            println "[INFO] Successfully removed temp file \"$redirectSite\".";
        else
            println "[ERR] Failed to remove temp file \"$redirectSite\"!" > /dev/stderr;
            exit 6;
        fi
    else
        println "[WARN] Temp file \"$redirectSite\" doesn't exist in \"$PWD\" directory!" > /dev/stderr;
    fi

    println "[INFO] Newset version of discord is \"$newestVersion\".";

    if [ "$installedVersion" = "$newestVersion" ]; then
        println "[INFO] No updates are available for discord.";
        exit 1;
    else
        println "[INFO] There is an update available for discord.";
        exit 0;
    fi
elif [ "$1" = "--upgrade" ]; then
    if ! cd /tmp; then
        println "[ERR] Failed to change working directory to \"/tmp\"!" > /dev/stderr;
    fi

    packagePath="$(generateFileName "discord.package" "30" "tar.gz")";

    println "[INFO] Downloading discord package…";

    if ! curl -sLo "$packagePath" "https://discord.com/api/download?platform=linux&format=tar.gz"; then
        println "[ERR] Failed to download discord package!" > /dev/stderr;
        if rm "$packagePath"; then
            println "[WARN] Successfully removed temp file \"$packagePath\"." > /dev/stderr;
            exit 7;
        else
            println "[WARN] Failed to remove temp file \"$packagePath\"." > /dev/stderr;
            exit 8;
        fi
    fi

    if ! tar -xf "$packagePath"; then
        println "[ERR] Failed to extract discord package!" > /dev/stderr;
        if rm "$packagePath"; then
            println "[WARN] Successfully removed temp file \"$packagePath\"." > /dev/stderr;
            exit 7;
        else
            println "[WARN] Failed to remove temp file \"$packagePath\"." > /dev/stderr;
            exit 8;
        fi
    fi

    if rm "$packagePath"; then
        println "[INFO] Successfully removed temp package file.";
    else
        println "[WARN] Failed to remove temp package file \"$packagePath\"" > /dev/stderr;
    fi

    # [ -d /lib64/discord ] && sudo rm -rf /lib64/discord;
    [ -d "$installDir" ] && sudo rm -rf "$installDir";

    if [ -L "/usr/bin/Discord" ]; then
        if sudo rm -f "/usr/bin/Discord"; then
            if sudo ln -s "$installDir/Discord" /usr/bin/Discord; then
                println "[INFO] Successfully linked \"/usr/bin/Discord\" to \"$installDir/Discord\"";
            else
                println "[INFO] Failed to link \"/usr/bin/Discord\" to \"$installDir/Discord\"";
            fi
        else
            println "[WARN] Failed to remove \"/usr/bin/Discord\". Link to \"$installDir/Discord\" will not be created automatically" > /dev/stderr;
        fi
    else
        println "[INFO] Link \"/usr/bin/Discord\" doesn't exist !";
        if sudo ln -s "$installDir/Discord" /usr/bin/Discord; then
            println "[INFO] Successfully linked \"/usr/bin/Discord\" to \"$installDir/Discord\"";
        else
            println "[INFO] Failed to link \"/usr/bin/Discord\" to \"$installDir/Discord\"";
        fi
    fi

    if sudo mv Discord "$installDir"; then
        println "[INFO] Successfully installed discord app.";
        exit 0;
    else
        println "[ERR] Failed to move \"$PWD/Discord\" directory to \"$installDir\"" > /dev/stderr;
        exit 9;
    fi
fi
