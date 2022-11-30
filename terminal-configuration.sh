#!/bin/bash

ZSH_DISABLE_COMPFIX="true"

print "\n========================================";
print "Checking local ~/.zshrc environment...";
print "Current Shell is $(echo $SHELL)"
printf '\e[8;40;230t';

NOW_DATE=$(date +"%F")
HOME_DIRECTORY=$(echo ~)

function resetTerminalConfig() {
    # FIXME: Cleanup with error handling

    LOCAL_SCRIPT_LOCATION="$HOME_DIRECTORY/.zshrc"

    # Backup current file
    if [[ -f "$LOCAL_SCRIPT_LOCATION" ]]; then
        mv $LOCAL_SCRIPT_LOCATION $LOCAL_SCRIPT_LOCATION-$NOW_DATE.bak
        print "\nLocal script is backed up. Listing directory to surface any cleanup."
        ls -hal ~/.*.bak
        print "\n"
    else
        print "$LOCAL_SCRIPT_LOCATION doesn't exist. No need to backup."
    fi
    
    # Fetch latest script
    curl -L https://raw.githubusercontent.com/himeshramjee/Chaiwala-Developer-Space/master/terminal-configuration.sh > $LOCAL_SCRIPT_LOCATION
    print "\nLocal config updated."

    print "Attempting to apply it..."
    source $LOCAL_SCRIPT_LOCATION
    print "Terminal reset done. Check for any errors."
}

function updateZshConfig() {
    print "Executing cp ~/workspaces/Oracle\ Content/backups/zshrc.sh ~/.zshrc..."
    cp ~/workspaces/Oracle\ Content/backups/zshrc.sh ~/.zshrc
    print "Copy Complete. Sourcing..."
    source ~/.zshrc
    print "Local script is updated.\n"
}

function getHomebrewInstallers() {
    if [[ -z "$1" ]]; then
        print "Usage: getHomebrewInstallers [install|uninstall]."
        return
    fi

    if [[ "$1" =~ "install" ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    elif [[ "$1" =~ "uninstall" ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"
    fi
}

function renewDomainCerts() {
    local renewCerts='n'

    printf 'Command to renew certs: sudo certbot -d ramjee.co.za -d *.ramjee.co.za --manual --preferred-challenges dns certonly\n'
    read -p "Upgrade SSL certs? [y|n] " renewCerts

    if [[ $renewCerts == 'y' || $renewCerts == 'Y' ]]; then
        printf '\nStart SLL cert renewall...\n'
        printf '\tsudo certbot -d ramjee.co.za -d *.ramjee.co.za --manual --preferred-challenges dns certonly\n'
        sudo certbot -d ramjee.co.za -d *.ramjee.co.za --manual --preferred-challenges dns certonly

        printf 'Restarting nginx service...(no output means success)\n'
        sudo service nginx restart

        printf 'Renewal function is done.\n'
    else 
        printf 'Skipping SSL cert renewal.\n'
    fi
}

function setJavaHome() {
    # https://mkyong.com/java/how-to-install-java-on-mac-osx/
    # https://medium.com/notes-for-geeks/java-home-and-java-home-on-macos-f246cab643bd
    print "\nJAVA_HOME is currently set to: $JAVA_HOME.\n"

    if [[ -z "$1" ]]; then
        print "Usage: setJavaHome [1.8|11|18]"
        print "NB! Version are dependent on what's installed on local system!"
        print "If the final version check isn't as you expect then don't use this script. Try manually setting JAVA_HOME to whichever version you need."

        print "\nListing available JVMs that can be used to set JAVA_HOME environment variable...\n"
        /usr/libexec/java_home -V
    else
        print "Exporting JAVA_HOME via '/usr/libexec/java_home -v $1'"
        export JAVA_HOME=$(/usr/libexec/java_home -v $1);
    fi

    print "\nConfirming 'java -version && print JAVA_HOME'\n"
    java -version
    print "\nJAVA_HOME: $JAVA_HOME"
    print "\nDone."
}

function setupPython() {
    # Dependency on pyenv being installed - see https://opensource.com/article/19/5/python-3-default-mac
    # Makes sure it's in zshrc and bash_profile config files
    # echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.zshrc

    # Ensure pyenv is setup and initialized
    if command -v pyenv 1>/dev/null 2>&1;
        then
            eval "$(pyenv init -)"
        else 
            # -p isn't compatible with zsh
            # read -p "Pyenv not installed. Brew it now? [Y/n]" inputInstallPyenv
            print "Pyenv not installed. Brew it now? [Y/n]"; read inputInstallPyenv

            if [[ "$inputInstallPyenv" =~ [yY] ]]; then
                if command -v brew 1>/dev/null 2>&1; then
                    brew install pyenv
                fi
            else 
                return -1
            fi

            eval "$(pyenv init -)"
    fi

    # Check current python version
    DEFAULT_PYTHON_VERSION="3.9.2"
    # DEFAULT_PYTHON_VERSION="2.7.18"
    PYTHON_VERSION_CHECK_STRING="Python $DEFAULT_PYTHON_VERSION"
    if [[ $(python --version 2>&1) =~ $PYTHON_VERSION_CHECK_STRING ]]; then
        print "$PYTHON_VERSION_CHECK_STRING is installed and likely the global default."
    else
        print "$PYTHON_VERSION_CHECK_STRING is not installed or is not the global default. "
    fi

    print "Listing available python versions around $PYTHON_VERSION_CHECK_STRING."
    pyenv install -l | grep $DEFAULT_PYTHON_VERSION
    print "Listing Done."

    print "\nConfirming 'python --version'"
    python --version
    print "Done.\n"
}

function installPython() {
    # Install different version?
    print "\nContinuing with python setup? [Y|n] "; read inputContinuePythonSetup;
    if [[ $inputContinuePythonSetup =~ [Yy] ]]; then
        print "What version of python do you want to install? Hit enter to install $DEFAULT_PYTHON_VERSION."; read inputPythonVersion
        if [[ -z $inputPythonVersion ]] then
            inputPythonVersion=$DEFAULT_PYTHON_VERSION
        fi

        pyenv install $inputPythonVersion

        print "Pyenv installation completed. Attempting to set version $inputPythonVersion as global default."
        pyenv global $inputPythonVersion
    fi
}

function installCLIs() {
    print "Install OCI CLI? [Y/n]"; read inputInstallOCICLI;
    if [[ $inputInstallOCICLI =~ [Yy] ]]; then
        brew update && brew install oci-cli
    fi

    print "Install AWS CLI? [Y/n]"; read inputInstallAWSCLI;
    if [[ $inputInstallAWSCLI =~ [Yy] ]]; then
        brew update && brew install aws-cli
    fi
}

function checkForLocalCert() {
    print "(mac-only) Checking local Keychain for specified cert..."
    if [[ ! -z "$1" ]]; then
        print "\t Command: security find-certificate -c '$1' -p -a"
        security find-certificate -c $1 -p -a
    fi
    print "Done."
}

function printCertInfo() {
    # $1 = path to file e.g. ./test-26-client-proxycert.pem
    openssl x509 -text -in $1 -noout
}

function launchChromeWithInsecureContent() {
    print "Executing cmd: '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --user-data-dir=/tmp/tempchrome --allow-running-insecure-content --incognito &'..."
    /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --user-data-dir=/tmp/tempchrome --allow-running-insecure-content --incognito &
    print "Done."
}

# Yubikey Hepers
# ===================================================================================
export OPENSC_LIB_VERSION="0.22.0"
export OPENSC_PATH='/usr/local/lib/opensc-pkcs11.so'

function reinitSSHAndOpenSC() {
    print "Geez, you're going with the last resort hey. Good luck!"

    print "If you need to check versions, try brew info|list opensc commands.\n"

    print "Uninstalling openssh"
    brew uninstall openssh

    print "\nUninstalling opensc"
    brew uninstall opensc

    print "\nInstalling openssh..."
    print "\t NOTE: The OpenSSH PKCS11 smartcard integration will not work from High Sierra onwards. If you need this functionality, unlink this formula, then install the OpenSC cask."
    print "Continue? [y|n]"; read inputContinueInstall;
    if [[ $inputContinueInstall =~ [Yy] ]] then
        brew install openssh
    fi

    print "\nInstalling opensc...Continue? [y|n]"; read inputContinueInstall;
    if [[ $inputContinueInstall =~ [Yy] ]] then
        brew install opensc
    fi

    print "\nRemoving $OPENSC_PATH..."
    rm -rf $OPENSC_PATH

    if [[ -f "/usr/local/Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so" ]]; then
        print "\nCopying opensc-pkcs11.so from Cellar..."
        cp /usr/local/Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so /usr/local/lib/
        print "Listing $OPENSC_PATH..."
        ll $OPENSC_PATH
    else
        print "\nCouldn't copy file. /usr/local/Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so not found."
        print "Listing /usr/local/Cellar/opensc/"
        ll /usr/local/Cellar/opensc/
    fi

    print "\nIf no errors are shown above, you also run reloadOpenSC to get the SC key loaded to your ssh-agent."
    print "Execute reloadOpenSC now? [y|n]"; read inputContinueReload;
    if [[ $inputContinueReload =~ [Yy] ]]; then
        loadSSHKeys
    fi

    print "\nDone."
}

function loadSSHKeys() {
    print "Running ssh-add -l..."
    ssh-add -l

    print "\nRemoving $OPENSC_PATH from ssh agent..."
    ssh-add -e $OPENSC_PATH

    if [[ $1 == "force" ]]; then
        print "\nKilling ssh-agent and pkcs11 smart card processes..."
        pkill -9 ssh-agent
        pkill -9 ssh-pkcs11-helper
        # export SSH_AUTH_SOCK=~/ssh-auth-sock
    fi

    print "\nCheck ssh agent status"
    eval $(ssh-agent)
    
    print "\nAdding $OPENSC_PATH back to ssh agent...this will ask for your yubi PIN"
    ssh-add -s $OPENSC_PATH

    print "\nAdding himesh.ramjee@oracle.com keys..."
    ssh-add ~/.ssh/himesh.ramjee@oracle.com
    
    print "\nAdding himesh.ramjee@gmail.com keys..."
    ssh-add ~/.ssh/himesh.ramjee@gmail.com

    print "\nConfirm all keys added; running ssh-add -l..."
    ssh-add -l
}

function showYubiKeyCommands() {
    print "Yubi serial \n\twas: 15400820\n\tand now is: 17141997"
    print "brew install yubico-piv-tool"
    print "Check how many retries attempts you have to guess PIN: \n\tyubico-piv-tool -a status | grep 'PIN'"
    print "Verify PIN (this will use up retry limit - seems I got about ~5 free attempts before the default 15 started counting down): \n\tyubico-piv-tool -a verify -P <PIN>"
    print "Show all slots: \n\tyubico-piv-tool -a status"
}

function setNodeVersion() {
    if [[ -z "$1" ]]; then
        print "Usage: setNodeVersion [12|14|latest]. If you see an error then verify that the version is actually installed. e.g. 'brew search node'"
        return
    fi

    if [[ "$1" =~ "latest" ]]; then
        brew link --overwrite node
    else
        brew link --overwrite node@$1
    fi
}

function showSystemCTLCommands() {
    print "systemctl list-units --type=service [--state=[active|failed]"
    print "ls -hal /etc/systemd/system/*.service"
    print "sudo systemd-analyze verify validates service daemon"
    print "sudo systemctl daemon-reload"
    print "sudo /usr/share/logstash/bin/system-install /etc/logstash/startup.options systemd generates a logstash.service file"
}

function targz () {
    tar -zcvf "$1.tar.gz" "$2"
}

function untar () {
    tar -xvf "$1"
}

function setDWLogLevel() {
    # print "[Older version 1.3.8] curl -k -X POST -d "" 'https://localhost:[AdminPort]/tasks/log-level?logger=com.payit.kafka.HelloWorld&level=DEBUG'"
    
    local newLogLevel='INFO'
    local targetPackage='ROOT'
    local applicationPort='19001'
    
    # Check Inputs
    # ---------------------------------------------------------------------
    if [[ ! -z "$1" ]]; then
        newLogLevel=$1
        print "New Log level set to $newLogLevel."
    else
        print "New Log level not specified as input. Defaulting to $newLogLevel."
    fi

    if [[ ! -z "$2" ]]; then
        targetPackage=$2
        print "Target package set to $targetPackage."
    else
        print "Target package not specified as input. Defaulting to $targetPackage."
    fi

    if [[ ! -z "$3" ]]; then
        applicationPort=$3
        print "Application port set to $applicationPort."
    else
        print "Application port not specified as input. Defaulting to $applicationPort."
    fi

    # Update log level
    # ---------------------------------------------------------------------
    print "\nSetting new log level for $targetPackage to $newLogLevel..."
    print "Command: curl -X POST -d 'logger=$targetPackage&level=$newLogLevel' https://localhost:$applicationPort/tasks/log-level"
    curl -X POST -d "logger=$targetPackage&level=$newLogLevel" https://localhost:$applicationPort/tasks/log-level
    
    # Check Application Health
    # ---------------------------------------------------------------------
    print "Pinging /healthcheck..."
    curl http://localhost:$applicationPort/healthcheck
}

# export NVM_DIR="$HOME/.nvm"
# [ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
# [ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Aliases
# =================================================================================================

# Local OS
alias ll='ls -hal'

# Local Environment setup

# Python initialization
setupPython

# Setup Java
setJavaHome 1.8

# Docker
alias dockc='docker-compose'
alias nxsup='docker-compose up -d nxs && docker-compose logs -f nxs'
alias hrwup='docker-compose up -d hrw && docker-compose logs -f hrw'
alias nlpup='docker-compose up -d node-nlp && docker-compose logs -f node-nlp'
alias axsup='docker-compose up -d axs && docker-compose logs -f axs'
alias resetcontainers='docker rm $(docker ps -a -q) -f'
alias resetimages='docker rmi $(docker images) -f'
alias resetnetworks='docker network prune'

# Kubernetes
alias kubectl-ll="kubectl get pods -l app!=himesh -o=jsonpath=\"{range .items[*]}{.metadata.name}{'\n'}{end}\""
alias kubectl-ga="clear && echo 'Deployments...\n' && kubectl get deployments && echo '\nServices...\n' && kubectl get services && echo '\nPods...\n' && kubectl get pods && echo '\nPod names...\n' && kubectl-ll"
alias kubectl-rr="kubectl rollout restart deployment $1"

# Maven
alias mvn-skoon="mvn clean install -DskipTests"
alias mvn-jacoco="mvn org.jacoco:jacoco-maven-plugin:0.8.5:prepare-agent test org.jacoco:jacoco-maven-plugin:0.8.5:report"
alias mvn-tests=" mvn -T 30C -o test -Dparallel=all -pl multicloud-database-adapter-api,multicloud-database-adapter-commons,multicloud-database-adapter-dal,multicloud-database-adapter-worker"

# Rancher
export PATH="$PATH:/Users/himeshramjee/.rd/bin"
# alias docker="/Users/himeshramjee/.rd/bin/docker"

print '\n$PATH: '$PATH
print "========================================\n";

print "Additional scripts"
print "========================================\n";

print "Sourcing ~/local-only-mc.sh"
source ~/local-only-mc.sh
print "Done.\n"
print "Sourcing ~/local-only-re.sh"
source ~/local-only-re.sh
print "Done.\n"

# if [[ -f "~/local-only-mc.sh" ]]; then
#     print "Sourcing local-only-mc.sh..."
#     source ~/local-only-mc.sh
# else
#     print "No local-only scripts to load."
#     ls -hal ~/local-only-*.sh
# fi
