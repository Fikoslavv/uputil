#!/bin/bash

UPUTIL_INSTALL_DIR="/usr/lib64/uputil";
UPUTIL_MODULES_DIR="$UPUTIL_INSTALL_DIR/modules";
UPUTIL_CONFIG_DIR="/etc/uputil.d";
UPUTIL_CHECKSUM_DIR="$UPUTIL_CONFIG_DIR/trusted.modules.d";
UPUTIL_CHECKSUM_FILE="$UPUTIL_CONFIG_DIR/uputil.checksum";

#Sets up variables based on passed short argumetns (e.g. -q)
function interpretShortArguments()
{
    local letter;
    
    while [ "$#" -gt 0 ]; do

        for ((i = 1; i < ${#1}; i++)); do

            letter="${1:i:1}";

            [[ "$letter" == "q" ]] && QUIET="0" && NO_INTERACT="0";
            [[ "$letter" == "v" ]] && VERBOSE="0";
            [[ "$letter" == "c" ]] && UPDATE="0";
            [[ "$letter" == "u" ]] && UPGRADE="0";
            [[ "$letter" == "i" ]] && INTEGRITY_CHECK="0";

        done

        shift;

    done
}

#Sets up variables based on passed long arguments (e.g. --quiet)
function interpretLongArguments()
{
    while [ "$#" -gt 0 ]; do

        [[ "$1" == "--quiet" ]] && QUIET="0" && NO_INTERACT="0";
        [[ "$1" == "--verbose" ]] && VERBOSE="0";
        [[ "$1" == "--update" ]] && UPDATE="0";
        [[ "$1" == "--upgrade" ]] && UPGRADE="0";
        [[ "$1" == "--integrity-check" ]] && INTEGRITY_CHECK="0";
        [[ "$1" == "--no-interact" ]] && NO_INTERACT="0";
        [[ "$1" == "--interactable-exit" ]] && AWAIT_INPUT_BEFORE_PROGRAM_EXIT="0";
        [[ "$1" == "--help" ]] && HELP="0";

        shift;

    done
}

#Sets up variables based on passed arguments
function interpretArguments()
{
    while [ "$#" -gt 0 ]; do

        if [[ "${1:0:2}" == "--" ]]; then

            interpretLongArguments "$1";

        elif [[ "${1:0:1}" == "-" ]]; then

            interpretShortArguments "$1";

        fi

        shift;

    done
}

function set_settings_to_default()
{
    QUIET="1";
    VERBOSE="1";
    NO_INTERACT="1";
    UPDATE="1";
    UPGRADE="1";
    INTEGRITY_CHECK="1";
    AWAIT_INPUT_BEFORE_PROGRAM_EXIT="1";
    HELP="1";
}

#Prints to stdout if QUIET is not set to 0
function print()
{
    get_is_quiet || printf "%s" "$*";
}

function println()
{
    get_is_quiet || printf "%s\n" "$*";
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

function get_is_update()
{
    [ "$UPDATE" -eq 0 ] && return 0;
    return 1;
}

function get_is_upgrade()
{
    [ "$UPGRADE" -eq 0 ] && return 0;
    return 1;
}

function get_is_integrity_check()
{
    [ "$INTEGRITY_CHECK" -eq 0 ] && return 0;
    return 1;
}

function get_is_no_interact()
{
    [ "$NO_INTERACT" -eq 0 ] && return 0;
    return 1;
}

function get_is_interactable_exit()
{
    [ "$AWAIT_INPUT_BEFORE_PROGRAM_EXIT" -eq 0 ] && return 0;
    return 1;
}

function get_is_help()
{
    [ "$HELP" -eq 0 ] && return 0;
    return 1;
}

#Prints to stdout if neither QUIET nor VERBOSE are set to 0
function debugPrint()
{
    get_is_verbose && print "[DEBUG] $*";
}

function debugPrintln()
{
    get_is_verbose && println "[DEBUG] $*";
}

function errorPrint()
{
    printf "[ERR] %s" "$*" > /dev/stderr;
}

function errorPrintln()
{
    printf "[ERR] %s\n" "$*" > /dev/stderr;
}

function warningPrint()
{
    printf "[WARN] %s" "$*" > /dev/stderr;
}

function warningPrintln()
{
    printf "[WARN] %s\n" "$*" > /dev/stderr;
}

function perform_exit()
{
    if ! get_is_quiet && get_is_interactable_exit; then

        println "Press anything to continue...";
        read -sn 1 > /dev/null 2> /dev/null;

    fi

    [ "$1" ] && exit "$1";
    exit 0;
}

function askUserIfModuleIsTrustworthy()
{
    get_is_quiet && return 2;
    get_is_no_interact && return 2;

    local module;
    module="$1";

    local checksumFilePath;
    checksumFilePath="$2";

    local untrustModule;
    untrustModule="chmod ugo-rwx $module";

    if askUser "Are you sure you want to trust that module?"; then

        println "Elevated privilages are neccesery to save module \"$(basename "$module")\" as trusted";

        if sudo -v; then

            println "Saving module \"$(basename "$module")\" as trusted";

            local checksum;
            checksum="$(sha512sum "$module" 2> /dev/null)";
            checksum="${checksum:0:128}  $module";

            [ -f "$checksumFilePath" ] && sudo rm -f "$checksumFilePath";

            sudo echo "$checksum" | sudo tee "$checksumFilePath" > /dev/null 2> /dev/null;
            checksum="";
            untrustModule="$untrustModule;rm -f $checksumFilePath";

            if ! sudo chmod ugo=r "$checksumFilePath" 2> /dev/null; then
                errorPrintln "Failed to change \"$checksumFilePath\" permissions to 444 !  Module \"$(basename "$module")\" will not be saved as trused !"
                $untrustModule;
                return 3;
            fi

            if ! sudo chown root:root "$checksumFilePath" 2> /dev/null; then
                errorPrintln "Failed to change owner of \"$checksumFilePath\" to root:root !  Module \"$(basename "$module")\" will not be saved as trusted !";
                $untrustModule;
                return 4;
            fi

        else

            println "Failed to elevate privilages. Module \"$("basename $module")\" won't be saved as trusted !";
            # $untrustModule;
            return 1;

        fi

    else

        println "Module \"$(basename "$module")\" will not be saved as trusted";
        # $untrustModule;
        return 1;

    fi

    pressedKey="";

    return 0;
}

function askUser()
{
    get_is_quiet && return 1;
    get_is_no_interact && return 1;

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

function checkUputilsTrustworthyness()
{
    debugPrintln "Checking trustworthyness of \"uputil\"";
    
    if ! [ -f "$UPUTIL_CHECKSUM_FILE" ]; then

        if askUser "Do you want to save \"uputil\" as trusted?"; then

            local checksum;
            local result;
            checksum="$(sha512sum "$(which uputil)")";
            result="$?";

            if [ "$result" -ne 0 ]; then

                errorPrintln "Failed to save \"uputil\" as trusted (exit code $result)";
                return 1;

            else

                println;
                println "Elevated privilages are neccesery to save \"uputil\" as trusted";

                if ! sudo -v; then

                    errorPrintln "Failed to elevate privilages. \"uputil\" will not be saved as trusted !";
                    return 1;

                fi

                sudo echo "$checksum" | sudo tee "$UPUTIL_CHECKSUM_FILE" > /dev/null 2> /dev/null;
                sudo chmod ugo=r "$UPUTIL_CHECKSUM_FILE" > /dev/null;
                sudo chown root:root "$UPUTIL_CHECKSUM_FILE" > /dev/null;

                println "\"uputil\" has been saved as trusted";
                println;

            fi

        else

            println "\"uputil\" will not be saved as trusted";
            return 1;

        fi

    elif [ -r "$UPUTIL_CHECKSUM_FILE" ]; then

        if ! sha512sum --check "$UPUTIL_CHECKSUM_FILE" > /dev/null 2> /dev/null; then

            errorPrintln "Sha512 checksum mismatch with checksum of trusted version !";
            return 1;

        else

            debugPrintln "\"uputil\" trustworthyness verified successfully";
            return 0;

        fi

    else

        errorPrintln "Failed to check trustworthyness of \"uputil\" !";
        return 2;

    fi
}

#Checks if sha512 checksums of module scripts are the same as cached ones in /etc/uputil.d/trusted.modules.d/module.checksum files
function checkModulesTrustworthyness()
{
    if ! cd "$UPUTIL_MODULES_DIR"; then

        errorPrintln "Failed to change working dir to \"$UPUTIL_MODULES_DIR\" !";
        return 2;

    fi

    local module;

    trustedModules=();

    # shellcheck disable=SC2044
    for module in $(find $UPUTIL_MODULES_DIR -maxdepth 1 -mindepth 1 2> /dev/null); do

        debugPrintln "Checking trustworthyness of module \"$module\"";

        if grep -Eq "5[05]5 root" <<< "$(stat -c "%a %U" "$module")"; then

            local checksumFilePath;
            checksumFilePath="$UPUTIL_CHECKSUM_DIR/$(basename "$module").checksum";

            if ! [ -f "$checksumFilePath" ]; then
            
                println "Module \"$(basename "$module")\" has not been trusted yet.";
                askUserIfModuleIsTrustworthy "$module" "$checksumFilePath" && trustedModules[${#trustedModules[@]}]="$module";
                println;
            
            elif ! grep -Eq "4[04]4 root" <<< "$(stat -c "%a %U" "$checksumFilePath")"; then

                warningPrintln "Checksum file of module \"$(basename "$module")\" has permissions different than 444 or its owner is not root !";
                askUserIfModuleIsTrustworthy "$module" "$checksumFilePath" && trustedModules[${#trustedModules[@]}]="$module";
                println;

            elif ! sha512sum --check --quiet "$checksumFilePath" 2> /dev/null > /dev/null; then

                println "Module \"$(basename "$module")\" has been changed since it was trusted.";
                askUserIfModuleIsTrustworthy "$module" "$checksumFilePath" && trustedModules[${#trustedModules[@]}]="$module";
                println;

            else

                debugPrintln "Module \"$(basename "$module")\" verified successfully";
                get_is_verbose && println;
                trustedModules[${#trustedModules[@]}]="$module";

            fi

        else

            warningPrintln "Module \"$(basename "$module")\" has permissions different than 555 or its owner is not root";
            println;

        fi

    done
}

function perform_check_update()
{
    if [ "${#trustedModules[@]}" -eq 0 ]; then

        println "[INFO] Running trustworthyness check...";
        println;

        if ! checkModulesTrustworthyness; then

            errorPrint "Failed to check trustworthyness of modules. Update canceled.";
            return 2;

        fi

    fi

    println "[INFO] Checking for updates...";

    upgradable=();

    local module;
    for module in "${trustedModules[@]}"; do

        get_is_verbose && println;
        get_is_verbose && println;
        debugPrintln "Triggering update checker of module \"$(basename "$module")\"...";

        local result;

        if get_is_verbose && ! get_is_quiet; then

            # "$module" --update;
            "$module" --check-for-update; #TODO => switch to new argument system...
            result="$?";

        else

            "$module" --check-for-update > /dev/null;
            result="$?";

        fi

        debugPrint "Module \"$(basename "$module")\" returned code $result ";

        if [ "$result" -eq 0 ]; then

            get_is_verbose && print "(update available)";

            upgradable[${#upgradable[@]}]="$module";

        elif [ "$result" -eq 1 ]; then

            get_is_verbose && print "(up to date)";

        else

            get_is_verbose && println "(error)";

            local msg;
            msg="Module \"$(basename "$module")\" returned code \"$result\" !";
            get_is_verbose && errorPrint "$msg";
            get_is_verbose || errorPrintln "$msg";
            msg="";

        fi

        result="";

        get_is_verbose && println;

    done

    println;

    if [ "${#upgradable[@]}" -gt 1 ]; then

        println "There are updates available reported by following modules ↓";

        for module in "${upgradable[@]}"; do

            println " => $(basename "$module")";

        done

    elif [ "${#upgradable[@]}" -eq 1 ]; then

        println "Module \"$(basename "$module")\" reported available update";

    else

        println "No module reported available updates";
        println "Nothing to do";

    fi

    [ "${#upgradable[@]}" -gt 0 ] && return 1;

    return 0;
}

function perform_upgrade()
{
    if [ "${#upgradable[@]}" -eq 0 ] && ( ! get_is_update ); then

        perform_check_update;

    fi

    if [ "${#trustedModules[@]}" -eq 0 ]; then

        println "Running trustworthyness check...";

        if ! checkModulesTrustworthyness; then

            errorPrintln "Failed to check trustworthyness of modules. Upgrade canceled.";

        fi

    fi

    get_is_verbose && println;
    debugPrintln "Comparing upgradeable list to trusted modules list...";

    local module;
    local i;
    for ((i = 0; i < "${#upgradable[@]}"; i++)); do

        module="${upgradable[$i]}";

        if ! grep -Eq "$module" <<< "${trustedModules[@]}"; then

            warningPrintln "Module \"$(basename "$module")\" was added to upgrade queue but it was not on trusted modules list. The module will not be included in that upgrade.";
            unset "upgradable[$i]";

        fi

    done
    module="";

    debugPrintln "Comparison of upgradeable and trusted modules lists done";

    if [ "${#upgradable[@]}" -eq 0 ]; then

        println "Upgrades completed";
        println "Nothing to do";
        return 0;

    fi

    println;
    println "Elevated privilages are neccesery to perform updates...";
    if ! sudo -v; then

        errorPrintln "Failed to elevate privilages. Upgrade canceled !";
        return 2;

    fi

    println;
    println "Running upgrades...";

    local successfulUpgrades;
    successfulUpgrades=();
    local failedUpgrades;
    failedUpgrades=();

    for module in "${upgradable[@]}"; do

        local result;

        debugPrintln "Triggering module \"$(basename "$module")\"...";

        if get_is_verbose && ! get_is_quiet; then
            "$module" --upgrade;
            result="$?";
        else
            "$module" --upgrade > /dev/null;
            result="$?";
        fi

        debugPrint "Module \"$(basename "$module")\" returned code $result ";

        if [ "$result" -eq 0 ]; then

            get_is_verbose && print "(ok)";
            successfulUpgrades["${#successfulUpgrades[@]}"]="$(basename "$module")";

        else

            get_is_verbose && print "(err)";
            failedUpgrades["${#failedUpgrades[@]}"]="$(basename "$module")";

        fi

        get_is_verbose && println;

    done
    module="";

    println "Upgrades completed";
    println;
    println "Upgrades summary ↓";

    if [ "${#successfulUpgrades[@]}" -gt 0 ]; then

        println " Successful upgrades ↓";

        for module in "${successfulUpgrades[@]}"; do

            println "  => $(basename "$module")";

        done
        module="";

    else

        println " No successful upgrades !";

    fi

    if [ "${#failedUpgrades}" -gt 0 ]; then

        println " Failed upgrades ↓";

        for module in "${failedUpgrades[@]}"; do

            println "  => $(basename "$module")";

        done
        module="";

        return 1;

    else

        println " No failed upgrades";

    fi

    return 0;
}

set_settings_to_default;
interpretArguments "$@";

checkUputilsTrustworthyness;
result="$?";
if [ "$result" -ne 0 ]; then
    exit "$result";
fi
unset result;

if get_is_help; then

    println "uputil [args]";

    println "Possible args ↓";
    println " --help => displays this message and quits";
    println " -q --quiet => supresses messages and sets --no-interact";
    println " -v --verbose => displays debug messages";
    println " -i --integrity-check => triggers integrity check of modules";
    println " -c --update => checks for updates and exits. Return code 0 and 1 are returned which mean up to date and updates available respectively";
    println " -u --upgrade => checks for updates and upgrades";
    println " --no-interact => automatically answers no to all questions";
    println " --interactable-exit => awaits user input before program ends";

    exit 0;

fi

if get_is_update; then

    perform_check_update;
    result=$?;

    if ! get_is_upgrade && ! get_is_integrity_check; then

        get_is_interactable_exit && println;

        perform_exit "$result";

    fi

    unset result;

fi

if get_is_integrity_check; then

    println "Triggering integrity check";

    checkModulesTrustworthyness;
    result=$?;

    print "Integrity check ";
    if [ "$result" -eq 0 ]; then
        println "succeeded";
    else
        println "failed";
    fi

    if ! get_is_upgrade; then

        get_is_interactable_exit && println;

        perform_exit "$result";

    fi

    unset result;

fi

if get_is_upgrade; then

    perform_upgrade;
    result="$?";

    trustedModules=();
    upgradable=();

    get_is_interactable_exit && println;
    perform_exit "$result";

fi
