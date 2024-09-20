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

function print()
{
    ! get_is_quiet && get_is_verbose && printf "%s" "$*";
}

function println()
{
    ! get_is_quiet && get_is_verbose && printf "%s\n" "$*";
}

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

        println "[ERR] Failed to switch pwd to \"/tmp\" !" > /dev/stderr;
        exit 255;

    fi

    println "[INFO] Running update check for thorium-browser";

    if insVersion=$(getVersionNumberFromString "$(thorium-browser --version)"); then
        println "[INFO] thorium-browser --version successfully executed";
    else
        println "[INFO] thorium-browser --version failed to execute";
        insVersion="null";
    fi

    println $'\n'"[INFO] Installed thorium-browser version -> $insVersion"$'\n';

    println "[INFO] Downloading thorium-browser latest github releases page...";

    rpFile="$(generateFileName "thorium-browser.github.releases.latest" 20 "html")";

    if downloadThoriumLatestReleasesPage "$rpFile"; then
        println "[INFO] Download of thorium-browser latest github releases page succeeded";
    else
        println "[ERROR] Failed to download thorium-browser latest github releases page" > /dev/stderr;

        if secureFileCleanup "$rpFile"; then
            println "[INFO] Cleaned $rpFile";
            return 3;
        else
            println "[WARNING] Failed to clean $rpFile" > /dev/stderr;
            return 4;
        fi
    fi

    currVersion="$(getVersionNumberFromString "$(getExpandedAssetsLinkFromFile "$rpFile")")";
    println $'\n'"[INFO] Newest version of thorium-browser -> $currVersion"$'\n';

    if secureFileCleanup "$rpFile"; then
        println "[INFO] Cleaned $rpFile";
    else
        println "[WARNING] Failed to clean $rpFile" > /dev/stderr;
        exit 5;
    fi

    println;

    cd "$previous_pwd" 2> /dev/null || println "[WARN] Failed to switch pwd to \"$previous_pwd\"...";

    if [ "$insVersion" != "$currVersion" ]; then
        println "[INFO] There's an update for thorium-browser available";
        exit 0;
    else
        println "[INFO] thorium-browser is up to date";
        exit 1;
    fi

elif [[ "$1" == "--upgrade" ]]; then
    previous_pwd="$PWD";

    if ! cd "/tmp"; then

        println "[ERROR] Failed to switch pwd to \"/tmp\" !" > /dev/stderr;
        exit 255;

    fi

    grPage="$(generateFileName "thorium-browser.github.releases.latest" 20 "html")";
    
    if downloadThoriumLatestReleasesPage "$grPage"; then
        println "[INFO] Download of thorium-browser latest github releases page succeeded";
    else
        println "[ERROR] Failed to download thorium-browser latest github releases page. Upgrade canceled" > /dev/stderr;

        if secureFileCleanup "$grPage"; then
            println "[INFO] Cleaned $grPage";
            exit 6;
        else
            println "[WARNING] Failed to clean $grPage" > /dev/stderr;
            exit 7;
        fi
    fi

    println;

    eaPage="$(generateFileName "thorium-browser.github.releases.latest.expanded.assets" 20 "html")";

    if downloadThoriumExpandedAssetsPage "$grPage" "$eaPage"; then
        println "[INFO] Download of expanded assets succeeded";
    else
        println "[ERROR] Failed to download thorium-browser latest expanded assets page. Upgrade canceled [url -> $eaPage]" > /dev/stderr;
        exit 8;
    fi

    println;

    if secureFileCleanup "$grPage"; then
        println "[INFO] Cleaned $grPage";
    else
        println "[WARNING] Failed to clean $grPage" > /dev/stderr;
    fi

    println $'\n'"[INFO] Downloading newest version of thorium-browser";

    tPackage="$(generateFileName "thorium-browser-latest" 20 "rpm")";
    packageDownloadLink="$(downloadThoriumPackage "$eaPage" "AVX2" ".rpm" "$tPackage")"
    packageDownloadStatus=$?;

    println "[INFO] Download of thorium-browser complete";

    if secureFileCleanup "$eaPage"; then
        println "[INFO] Cleaned $eaPage";
    else
        println "[WARNING] Failed to clean $eaPage" > /dev/stderr;
    fi

    println;

    if [ $packageDownloadStatus -eq 0 ]; then
        println "[INFO] $tPackage downloaded successfully";
    else
        println "[ERROR] Failed to download \"$tPackage\". Upgrade canceled [url -> $packageDownloadLink]" > /dev/stderr;

        if secureFileCleanup "$tPackage"; then
            println "[INFO] Cleaned $tPackage";
            exit 9;
        else
            println "[WARNING] Failed to clean $tPackage" > /dev/stderr;
            exit 10;
        fi
    fi

    println $'\n[INFO] Attempting to install thorium-browser...\n';

    if sudo dnf install "$tPackage" -y; then
        println $'\n[INFO] thorium-browser installed successfully';
    else
        println $'\n[ERROR] Failed to install thorium-browser' > /dev/stderr;
        
        if secureFileCleanup "$tPackage"; then
            println "[INFO] Cleaned $tPackage";
        else
            println "[WARNING] Failed to clean $tPackage" > /dev/stderr;
            exit 11;
        fi
    fi

    if secureFileCleanup "$tPackage"; then
        println "[INFO] Cleaned $tPackage";
    else
        println "[WARNING] Failed to clean $tPackage" > /dev/stderr;
        exit 11;
    fi

    cd "$previous_pwd" 2> /dev/null || println "[WARN] Failed to switch pwd to \"$previous_pwd\"..." > /dev/stderr;

    println $'\n[INFO] '"$0 upgrade process completed successfully";
    exit 0;
else
    println "[ERROR] Unknown argument $1" > /dev/stderr;
    exit 2;
fi