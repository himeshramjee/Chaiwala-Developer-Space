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

function getHomebrewInstaller() {
    # FIXME: Cleanup with error handling
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    print "Homebrew download is done (check for errors before executing the install.sh file)."
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
OPENSC_LIB_VERSION="0.22.0"

function reinitSSHAndOpenSC() {
    print "Geez, you're going with the last resort hey. Good luck!"

    print "If you need to check versions, try brew info|list opensc commands.\n"

    print "Uninstalling openssh"
    brew uninstall openssh

    print "\nUninstalling opensc"
    brew uninstall opensc

    print "\n\t NOTE: The OpenSSH PKCS11 smartcard integration will not work from High Sierra onwards. If you need this functionality, unlink this formula, then install the OpenSC cask."
    print "\nInstalling openssh...Continue? [y|n]"; read inputContinueInstall;
    if [[ $inputContinueInstall =~ [Yy] ]] then
        brew install openssh
    fi

    read -p "\nInstalling opensc...Continue? [y|n]" inputContinueInstall
    if [[ $inputContinueInstall =~ [Yy] ]] then
        brew install opensc
    fi

    print "\nRemoving /usr/local/lib/opensc-pkcs11.so..."
    cd /usr/local/lib/
    rm -rf opensc-pkcs11.so

    OPENSC_LIB_VERSION="0.22.0"
    if [[ -f "../Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so" ]]; then
        print "\n\t Copying from Cellar..."
        cp ../Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so .
    else
        print "\n\t Couldn't copy file to ${PWD}. ../Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so not found."
        ll ../Cellar/opensc/
    fi

    print "\nDone."
}

function reloadOpenSC() {
    print 'Listing current SSH Identities registered with SSH Agent'
    ssh-add -l
    print '\tDone.'

    OPENSC_LIB_INSTALLED_PATH="/usr/local/Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so"
    OPENSC_LIB_PATH='/usr/local/lib/opensc-pkcs11-local.so'
    # ln -s $OPENSC_LIB_INSTALLED_PATH $OPENSC_LIB_PATH
    
    print 'Removing previous smart card/key...'
    ssh-add -e $OPENSC_LIB_PATH >> /dev/null
    if [ $? -gt 0 ]; then
        print "\tFailed to remove previous card"
    fi
    print "\tDone."
    
    print "Killing ssh-agent process..."
    pkill -9 ssh-agent
    print "\tDone."

    print "Killing ssh-pkcs11-helper..."
    pkill -9 ssh-pkcs11-helper
    print "\tDone."

    print "Starting ssh agent..."
    export SSH_AUTH_SOCK='~/ssh-auth-sock'
    ssh-agent -s
    print "\tDone."
    
    print "Adding to agent..."
    ssh-add -s $OPENSC_LIB_PATH
    print "\tDone."

    print "Done."
}

function showYubiKeyCommands() {
    print "Yubi serial \n\twas: 15400820\n\tand now is: 17141997"
    print "brew install yubico-piv-tool"
    print "Check how many retries attempts you have to guess PIN: \n\tyubico-piv-tool -a status | grep 'PIN'"
    print "Verify PIN (this will use up retry limit - seems I got about ~5 free attempts before the default 15 started counting down): \n\tyubico-piv-tool -a verify -P <PIN>"
    print "Show all slots: \n\tyubico-piv-tool -a status"

    print "\nAlso be sure to check out pic-tools repo - last known location"
    print "\t/Users/himeshramjee/workspaces/dev-tools/pic-tools/scripts/bin"
}

function pickyThisShellIs() {
    if [[ $1 == "force" ]]; then
        print "Killing ssh-agent and pkcs11 smart card processes..."
        pkill -9 ssh-agent
        pkill -9 ssh-pkcs11-helper

        export OPENSC='/usr/local/lib/opensc-pkcs11.so'
        # export SSH_AUTH_SOCK=~/ssh-auth-sock
        
        print "Adding $OPENSC to agent..."
        ssh-add -s $OPENSC
    else
        print "Running source /Users/himeshramjee/workspaces/dev-tools/pic-tools/scripts/*.env..."
        source /Users/himeshramjee/workspaces/dev-tools/pic-tools/scripts/*.env

        print "Running cd /Users/himeshramjee/workspaces/dev-tools/pic-tools/scripts/bin..."
        cd /Users/himeshramjee/workspaces/dev-tools/pic-tools/scripts/bin

        print "Running pic-tools so you can cache ssh keys..."
        pic-yubi
    fi

    print "Check ssh agent status"
    eval $(ssh-agent)

    print "Confirming yubi-keys added by Running ssh-add -l..."
    ssh-add -l
}

function startLocalKiev() {
    # podman machine init --cpus 2 --disk-size 32 --memory 4096
    # podman machine start
    podman run --rm -p 1521:1521 --shm-size 1g iod-example-pdb
}

# Aliases
# =================================================================================================

# Local OS
alias ll='ls -hal'

# Local Environment setup

# Python initialization
setupPython

# Setup Java
# export JAVA_HOME='/Library/Java/JavaVirtualMachines/jdk-11.0.13.jdk/Contents/Home'
export JAVA_HOME=`/usr/libexec/java_home -v 11`
# export JAVA_HOME=`/usr/libexec/java_home -v 1.8.0_292`
# export JAVA_HOME='/usr/local/Cellar/openjdk/17'
# export JAVA_HOME='/usr/local/Cellar/openjdk/17/libexec/openjdk.jdk/Contents/Home'
# export PATH=$PATH:$JAVA_HOME
# export PATH="/usr/local/opt/openjdk@8/bin:$PATH"
print "\nConfirming 'java -version'"
java -version

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

print '\n$PATH: '$PATH

# autoload -U +X bashcompinit && bashcompinit
# complete -o nospace -C /usr/local/bin/terraform terraform

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

print "========================================\n";
