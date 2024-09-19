#!/bin/bash

function getThoriumVersionRegex()
{
    echo "(([0-9]+[.])+[0-9]+){1}";
}

function downloadThoriumLatestReleasesPage()
{
    if [ -z "$1" ]; then
        return 1;
    fi

    curl -sL "https://github.com/Alex313031/thorium/releases/latest" -o "$1";
    return 0;
}

#Path to file [$1]
function secureFileCleanup()
{
    if [ -f "$1" ]; then
        rm "$1";
        return 0;
    else
        return 1;
    fi
}

#Prefix[$1].randomHex"$2"DigitNumber.Suffix[$3] (Dots indcluded)
function generateFileName()
{
    fileName="$1.$(openssl rand -hex "$2").$3";
    while [ -f "$fileName" ]; do
        fileName="$1.$(openssl rand -hex "$2").$3";
    done

    echo "$fileName";
}

#PathToHtmlFile[$1]
function getExpandedAssetsLinkFromFile()
{
    if [ -f  "$1" ]; then
        grep -Eo "https://github.com/Alex313031/thorium/releases/expanded_assets/M$(getThoriumVersionRegex)" "$1";
        return 0;
    else
        return 1;
    fi
}

#String[$1]
function getVersionNumberFromString()
{
    grep -Eo "$(getThoriumVersionRegex)" <<< "$1";
}

#PathToHtmlFile[$1] OutputFileName[$2]
function downloadThoriumExpandedAssetsPage()
{
    curl -s "$(getExpandedAssetsLinkFromFile "$1")" -o "$2";
}

#GithubAssetsHtmlFile[$1] ThoriumVariant(AVX,AVX2,SSE3)[$2] PackageExtension[$3](.deb,.rpm,.zip)
function getPackageUrlFromGAHF()
{
    grep -Eo "/Alex313031/thorium/releases/download/M$(getThoriumVersionRegex)/thorium-browser_$(getThoriumVersionRegex)_$2$3" "$1";
}

#GithubAssetsHtmlFile[$1] ThoriumVariant(AVX,AVX2,SSE3)[$2] PackageExtension[$3](.deb,.rpm,.zip) OutputFilePath[$4]
function downloadThoriumPackage()
{
    local link;
    local status;
    link="https://github.com$(getPackageUrlFromGAHF "$1" "$2" "$3")";
    status=$?;
    curl -sL "$link" -o "$4";
    echo "$link";
    return $status;
}

if [[ "$1" == "--check-for-update" ]]; then
    previous_pwd="$PWD";

    if ! cd "/tmp"; then

        echo "[ERR] Failed to switch pwd to \"/tmp\" !";
        exit 255;

    fi

    echo "[INFO] Running update check for thorium-browser";

    if insVersion=$(getVersionNumberFromString "$(thorium-browser --version)"); then
        echo "[INFO] thorium-browser --version successfully executed";
    else
        echo "[INFO] thorium-browser --version failed to execute";
        insVersion="null";
    fi

    echo $'\n'"[INFO] Installed thorium-browser version -> $insVersion"$'\n';

    echo "[INFO] Downloading thorium-browser latest github releases page...";

    rpFile="$(generateFileName "thorium-browser.github.releases.latest" 20 "html")";

    if downloadThoriumLatestReleasesPage "$rpFile"; then
        echo "[INFO] Download of thorium-browser latest github releases page succeeded";
    else
        echo "[ERROR] Failed to download thorium-browser latest github releases page";

        if secureFileCleanup "$rpFile"; then
            echo "[INFO] Cleaned $rpFile";
            return 3;
        else
            echo "[WARNING] Failed to clean $rpFile"
            return 4;
        fi
    fi

    currVersion="$(getVersionNumberFromString "$(getExpandedAssetsLinkFromFile "$rpFile")")";
    echo $'\n'"[INFO] Newest version of thorium-browser -> $currVersion"$'\n';

    if secureFileCleanup "$rpFile"; then
        echo "[INFO] Cleaned $rpFile";
    else
        echo "[WARNING] Failed to clean $rpFile";
        exit 5;
    fi

    echo;

    cd "$previous_pwd" 2> /dev/null || echo "[WARN] Failed to switch pwd to \"$previous_pwd\"...";

    if [ "$insVersion" != "$currVersion" ]; then
        echo "[INFO] There's an update for thorium-browser available";
        exit 0;
    else
        echo "[INFO] thorium-browser is up to date";
        exit 1;
    fi

elif [[ "$1" == "--upgrade" ]]; then
    previous_pwd="$PWD";

    if ! cd "/tmp"; then

        echo "[ERR] Failed to switch pwd to \"/tmp\" !";
        exit 255;

    fi

    grPage="$(generateFileName "thorium-browser.github.releases.latest" 20 "html")";
    
    if downloadThoriumLatestReleasesPage "$grPage"; then
        echo "[INFO] Download of thorium-browser latest github releases page succeeded";
    else
        echo "[ERROR] Failed to download thorium-browser latest github releases page. Upgrade canceled";

        if secureFileCleanup "$grPage"; then
            echo "[INFO] Cleaned $grPage";
            exit 6;
        else
            echo "[WARNING] Failed to clean $grPage";
            exit 7;
        fi
    fi

    echo;

    eaPage="$(generateFileName "thorium-browser.github.releases.latest.expanded.assets" 20 "html")";

    if downloadThoriumExpandedAssetsPage "$grPage" "$eaPage"; then
        echo "[INFO] Download of expanded assets succeeded";
    else
        echo "[ERROR] Failed to download thorium-browser latest expanded assets page. Upgrade canceled [url -> $eaPage]";
        exit 8;
    fi

    echo;

    if secureFileCleanup "$grPage"; then
        echo "[INFO] Cleaned $grPage";
    else
        echo "[WARNING] Failed to clean $grPage";
    fi

    echo $'\n'"[INFO] Downloading newest version of thorium-browser";

    tPackage="$(generateFileName "thorium-browser-latest" 20 "rpm")";
    packageDownloadLink="$(downloadThoriumPackage "$eaPage" "AVX2" ".rpm" "$tPackage")"
    packageDownloadStatus=$?;

    echo "[INFO] Download of thorium-browser complete";

    if secureFileCleanup "$eaPage"; then
        echo "[INFO] Cleaned $eaPage";
    else
        echo "[WARNING] Failed to clean $eaPage";
    fi

    echo;

    if [ $packageDownloadStatus -eq 0 ]; then
        echo "[INFO] $tPackage downloaded successfully";
    else
        echo "[ERROR] Failed to download \"$tPackage\". Upgrade canceled [url -> $packageDownloadLink]";

        if secureFileCleanup "$tPackage"; then
            echo "[INFO] Cleaned $tPackage";
            exit 9;
        else
            echo "[WARNING] Failed to clean $tPackage";
            exit 10;
        fi
    fi

    echo $'\n[INFO] Attempting to install thorium-browser...\n';

    if sudo dnf install "$tPackage" -y; then
        echo $'\n[INFO] thorium-browser installed successfully';
    else
        echo $'\n[ERROR] Failed to install thorium-browser';
        
        if secureFileCleanup "$tPackage"; then
            echo "[INFO] Cleaned $tPackage";
        else
            echo "[WARNING] Failed to clean $tPackage";
            exit 11;
        fi
    fi

    if secureFileCleanup "$tPackage"; then
        echo "[INFO] Cleaned $tPackage";
    else
        echo "[WARNING] Failed to clean $tPackage";
        exit 11;
    fi

    cd "$previous_pwd" 2> /dev/null || echo "[WARN] Failed to switch pwd to \"$previous_pwd\"...";

    echo $'\n[INFO] '"$0 upgrade process completed successfully";
    exit 0;
else
    echo "[ERROR] Unknown argument $1";
    exit 2;
fi