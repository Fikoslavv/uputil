#!/bin/bash

#Prefix[$1].randomHex"$2"DigitNumber.Suffix[$3] (Dots indcluded)
function generateFileName()
{
    fileName="$1.$(openssl rand -hex "$2").$3";
    while [ -f "$fileName" ]; do
        fileName="$1.$(openssl rand -hex "$2").$3";
    done

    echo "$fileName";
}

installDir="/usr/lib64/discord";

if [[ "$1" == "--check-for-update" ]]; then
    echo "[INFO] Running update check for discord";

    if ! cd "/tmp"; then
        echo "[ERR] Failed to change working directory to \"/tmp\"!";
        exit 2;
    fi

    redirectSite="$(generateFileName "discord.redirect" "30" "html")";

    if ! curl -so "$redirectSite" "https://discord.com/api/download?platform=linux&format=tar.gz"; then
        echo "[ERR] Failed to download redirect site from \"https://discord.com/api/download?platform=linux&format=tar.gz\".";

        if [ -f "$redirectSite" ]; then
            if rm "$redirectSite"; then
                echo "[INFO] Successfully removed temp file \"$redirectSite\".";
                exit 3;
            else
                echo "[ERR] Failed to remove temp file \"$redirectSite\"!";
                exit 4;
            fi
        else
            echo "[WARN] Temp file \"$redirectSite\" doesn't exist in \"$PWD\" directory!";
            exit 5;
        fi
    fi

    # if [ -f /lib64/discord/resources/build_info.json ]; then
    if [ -f "$installDir/resources/build_info.json" ]; then
        installedVersion="$(cat $installDir/resources/build_info.json | grep -Eo "([0-9]*[.])*[0-9]+")";
    else
        installedVersion="null";
    fi

    echo "[INFO] Installed version of discord is \"$installedVersion\".";

    newestVersion="$(grep -Eo "([0-9]*[.])*[0-9]+" <<< cat "$PWD/$redirectSite" | tail -n 1)";

    if [ -f "$redirectSite" ]; then
        if rm "$redirectSite"; then
            echo "[INFO] Successfully removed temp file \"$redirectSite\".";
        else
            echo "[ERR] Failed to remove temp file \"$redirectSite\"!";
            exit 6;
        fi
    else
        echo "[WARN] Temp file \"$redirectSite\" doesn't exist in \"$PWD\" directory!";
    fi

    echo "[INFO] Newset version of discord is \"$newestVersion\".";

    if [ "$installedVersion" = "$newestVersion" ]; then
        echo "[INFO] No updates are available for discord.";
        exit 1;
    else
        echo "[INFO] There is an update available for discord.";
        exit 0;
    fi
elif [ "$1" = "--upgrade" ]; then
    if ! cd /tmp; then
        echo "[ERR] Failed to change working directory to \"/tmp\"!";
    fi

    packagePath="$(generateFileName "discord.package" "30" "tar.gz")";

    echo "[INFO] Downloading discord package…";

    if ! curl -sLo "$packagePath" "https://discord.com/api/download?platform=linux&format=tar.gz"; then
        echo "[ERR] Failed to download discord package!";
        if rm "$packagePath"; then
            echo "[WARN] Successfully removed temp file \"$packagePath\".";
            exit 7;
        else
            echo "[WARN] Failed to remove temp file \"$packagePath\".";
            exit 8;
        fi
    fi

    if ! tar -xf "$packagePath"; then
        echo "[ERR] Failed to extract discord package!";
        if rm "$packagePath"; then
            echo "[WARN] Successfully removed temp file \"$packagePath\".";
            exit 7;
        else
            echo "[WARN] Failed to remove temp file \"$packagePath\".";
            exit 8;
        fi
    fi

    if rm "$packagePath"; then
        echo "[INFO] Successfully removed temp package file.";
    else
        echo "[WARN] Failed to remove temp package file \"$packagePath\"";
    fi

    # [ -d /lib64/discord ] && sudo rm -rf /lib64/discord;
    [ -d "$installDir" ] && sudo rm -rf "$installDir";

    if [ -L "/usr/bin/Discord" ]; then
        if sudo rm -f "/usr/bin/Discord"; then
            if sudo ln -s "$installDir/Discord" /usr/bin/Discord; then
                echo "[INFO] Successfully linked \"/usr/bin/Discord\" to \"$installDir/Discord\"";
            else
                echo "[INFO] Failed to link \"/usr/bin/Discord\" to \"$installDir/Discord\"";
            fi
        else
            echo "[WARN] Failed to remove \"/usr/bin/Discord\". Link to \"$installDir/Discord\" will not be created automatically";
        fi
    else
        echo "[INFO] Link \"/usr/bin/Discord\" doesn't exist !";
        if sudo ln -s "$installDir/Discord" /usr/bin/Discord; then
            echo "[INFO] Successfully linked \"/usr/bin/Discord\" to \"$installDir/Discord\"";
        else
            echo "[INFO] Failed to link \"/usr/bin/Discord\" to \"$installDir/Discord\"";
        fi
    fi

    if sudo mv Discord "$installDir"; then
        echo "[INFO] Successfully installed discord app.";
        exit 0;
    else
        echo "[ERR] Failed to move \"$PWD/Discord\" directory to \"$installDir\"";
        exit 9;
    fi
fi
