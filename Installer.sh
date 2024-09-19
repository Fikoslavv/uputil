#!/bin/bash

UPUTIL_INSTALL_DIR="/usr/lib64/uputil";
UPUTIL_MODULES_DIR="$UPUTIL_INSTALL_DIR/modules";
UPUTIL_CONFIG_DIR="/etc/uputil.d";
UPUTIL_CHECKSUM_DIR="$UPUTIL_CONFIG_DIR/trusted.modules.d";
UPUTIL_CHECKSUM_FILE="$UPUTIL_CONFIG_DIR/uputil.checksum";

function print()
{
    printf "%s" "$*";
}

function println()
{
    printf "%s\n" "$*";
}

function errorPrint()
{
    print "[ERR] $*" > /dev/stderr;
}

function errorPrintln()
{
    println "[ERR] $*" > /dev/stderr;
}

function askUser()
{
    print "$* (y/n): ";
    local pressedKey;
    while ! grep -Eq "[yYnN]" <<< "$pressedKey"; do read -sn 1 pressedKey; done
    println "$pressedKey";

    if grep -Eq "[yY]" <<< "$pressedKey"; then
        return 0;
    else
        return 1;
    fi
}

if ! askUser "Do you want to install uputil?"; then
    errorPrintln "Install cancelled";
    exit 255;
fi
println;

println "Elevated privilages are neccesery to install uputil";
if ! sudo -v; then
    errorPrintln "Failed to elevate privilages. Install cancelled";
    exit 254;
fi
println;

if ! cd "$(dirname "$0")"; then
    errorPrintln "Failed to switch working directory to \"$(dirname "$0")\" !";
    exit 253;
fi

UPUTIL_LINKS=();
UPUTIL_LINKS["${#UPUTIL_LINKS[@]}"]="uputil";
UPUTIL_LINKS["${#UPUTIL_LINKS[@]}"]="$UPUTIL_INSTALL_DIR/UpdateUtility.sh";
UPUTIL_LINKS["${#UPUTIL_LINKS[@]}"]="uputil-launcher";
UPUTIL_LINKS["${#UPUTIL_LINKS[@]}"]="$UPUTIL_INSTALL_DIR/Launcher.sh";

for ((x = 0; x + 1 < "${#UPUTIL_LINKS[@]}"; x += 2)); do
    ulink="${UPUTIL_LINKS["$x"]}";
    ulinkdir="${UPUTIL_LINKS["$(("$x" + 1))"]}";
    if which "$ulink" > /dev/null 2> /dev/null; then
        linkdir="$(readlink -f "$(which "$ulink")")";

        if [ "$linkdir" != "$ulinkdir" ]; then
            if ! askUser "There already is link called \"$ulink\" that doesn't point to $ulinkdir (instead points to $linkdir). Do you want to have the link removed?"; then
                errorPrintln "Install cancelled";
                exit 3;
            else
                sudo rm -f "$(which "$ulink")" && println "The link has been successfully removed" && println;
            fi
        fi
    fi
done
unset ulink;
unset linkdir;
unset ulinkdir;

sudo ln -s "${UPUTIL_LINKS[1]}" "/usr/bin/${UPUTIL_LINKS[0]}" > /dev/null 2> /dev/null;
sudo ln -s "${UPUTIL_LINKS[3]}" "/usr/bin/${UPUTIL_LINKS[2]}" > /dev/null 2> /dev/null;
unset UPUTIL_LINKS;

UPUTIL_DIRS=();
UPUTIL_DIRS["${#UPUTIL_DIRS[@]}"]="$UPUTIL_INSTALL_DIR";
UPUTIL_DIRS["${#UPUTIL_DIRS[@]}"]="$UPUTIL_MODULES_DIR";
UPUTIL_DIRS["${#UPUTIL_DIRS[@]}"]="$UPUTIL_CONFIG_DIR";
UPUTIL_DIRS["${#UPUTIL_DIRS[@]}"]="$UPUTIL_CHECKSUM_DIR";

for dir in "${UPUTIL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        if ! askUser "Directory \"$dir\" already exists. Do you want to have it (and its contents) removed?"; then
            errorPrintln "Install cancelled";
            exit 4;
        else
            sudo rm -rf "$dir" && println "Directory \"$dir\" has been removed successfully" && println;
        fi
    fi
done
unset dir;
unset UPUTIL_DIRS;

sudo mkdir "$UPUTIL_INSTALL_DIR";
sudo mkdir "$UPUTIL_MODULES_DIR";
sudo mkdir "$UPUTIL_CONFIG_DIR";
sudo mkdir "$UPUTIL_CHECKSUM_DIR";

sudo cp ./UpdateUtility.sh "$UPUTIL_INSTALL_DIR/UpdateUtility.sh";
sudo cp ./Launcher.sh "$UPUTIL_INSTALL_DIR/Launcher.sh";
sudo cp -r ./modules "$UPUTIL_INSTALL_DIR/";

sudo chmod -R ugo=rx "$UPUTIL_INSTALL_DIR";
sudo chown -R root:root "$UPUTIL_INSTALL_DIR";

sha512sum "$(which uputil)" | sudo tee "$UPUTIL_CHECKSUM_FILE" > /dev/null 2> /dev/null;

sudo chmod -R ugo=r "$UPUTIL_CONFIG_DIR";
sudo chmod ugo=rx "$UPUTIL_CONFIG_DIR";
sudo chmod ugo=rx "$UPUTIL_CHECKSUM_DIR";
sudo chown -R root:root "$UPUTIL_CONFIG_DIR";

if askUser "Do you want to remove \"$PWD\" (the directory the install script is in)?"; then
    sudo rm -rf "$PWD";
fi

sudo -k;

println "Install completed";
