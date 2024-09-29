#!/bin/bash

ZSH_DISABLE_COMPFIX="true"
print "\n=======================================================================================";
print "Checking local ~/.zshrc environment...";
print "Current Shell is $(echo $SHELL)"
printf '\e[8;40;230t';

NOW_DATE=$(date +"%F")
HOME_DIRECTORY=$(echo ~)
export BACKUPS_FOLDER="$HOME_DIRECTORY/workspaces/OracleContent/backups"

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
    print "Executing cp $BACKUPS_FOLDER/zshrc.sh ~/.zshrc..."
    cp $BACKUPS_FOLDER/zshrc.sh ~/.zshrc
    print "Copy Complete. Sourcing..."
    source ~/.zshrc
    print "Local script is updated.\n"
}

function updateOciCliConfig() {
    print "Executing: cp $CLI_BACKUP_UP_PATH/oci-config/oci-config.config $HOME_DIRECTORY/.oci/config"
    cp $CLI_BACKUP_UP_PATH/oci-config/oci-config.config $HOME_DIRECTORY/.oci/config
    print "Updating file permissions with: chmod 0600 ~/.oci/config"
    chmod 0600 ~/.oci/config
    print "Done."
}

function loadBrew() {
    if [[ ! -d "/opt/homebrew" && ! -d "/usr/local/bin/brew" ]]; then
        print "Brew not found. Install? [y|n] "; read inputBrewInstall
        if [[ $inputBrewInstall =~ [yY] ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
            print "\nInstall should be done. Adding to path and adding exports..."
            # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"
        fi
    fi

    # if command -v brew &> /dev/null; then
    if [[ -d "/opt/homebrew/bin" || -d "/usr/local/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        print "Whoops! Brew not found bruuuu."
    fi
}

function renewDomainCerts() {
    local renewCerts='n'

    printf 'Command to renew certs: sudo certbot -d ramjee.co.za -d *.ramjee.co.za --manual --preferred-challenges dns certonly\n'
    read -p "Upgrade SSL certs? [y|n] " renewCerts

    if [[ $renewCerts =~ [yY] ]]; then
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
    if ! command -v java &> /dev/null; then
        print "\nSetting up Java..."
        # https://mkyong.com/java/how-to-install-java-on-mac-osx/
        # https://medium.com/notes-for-geeks/java-home-and-java-home-on-macos-f246cab643bd
        print "JAVA_HOME is currently set to: $JAVA_HOME."

        if [[ -z "$1" ]]; then
            print "Usage: setJavaHome [1.8|11|17|18]"
            print "NB! Version are dependent on what's installed on local system!"
            print "If the final version check isn't as you expect then don't use this script. Try manually setting JAVA_HOME to whichever version you need."

            print "\nListing available JVMs that can be used to set JAVA_HOME environment variable...\n"
            /usr/libexec/java_home -V
        else
            print "Exporting JAVA_HOME via '/usr/libexec/java_home -v $1'"
            export JAVA_HOME=$(/usr/libexec/java_home -v $1);
        fi

        # print "Confirming 'java -version && print JAVA_HOME'\n"
        java -version
        print "JAVA_HOME: $JAVA_HOME"
        print "Done."
    fi
}

DEFAULT_PYTHON_VERSION="3.12"
function installPython() {
    print "\nInstall Python? [Y/n]"; read inputInstallPython
    if [[ "$inputInstallPython" =~ [yY] ]]; then
        print "What version of python do you want to install? Hit enter to install $DEFAULT_PYTHON_VERSION."; read inputPythonVersion
        if [[ -z $inputPythonVersion ]] then
            inputPythonVersion=$DEFAULT_PYTHON_VERSION
        fi

        pyenv install $inputPythonVersion

        print "Executing: pyenv global $inputPythonVersion to update default python version"
        pyenv global $inputPythonVersion
    fi
}

function setupPyenv() {
    print "\nSetting up Python..."
    # Dependency on pyenv being installed - see https://opensource.com/article/19/5/python-3-default-mac
    # https://opensource.com/article/20/4/pyenv
    # Makes sure it's in zshrc and bash_profile config files
    # echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.zshrc

    # Ensure pyenv is setup and initialized
    # if ! command -v pyenv 1>/dev/null; then
    if ! command -v pyenv &> /dev/null; then
        # -p isn't compatible with zsh
        # read -p "Pyenv not installed. Brew it now? [Y/n]" inputInstallPyenv
        print "Pyenv not installed. Brew it now? [Y/n]"; read inputInstallPyenv
        if [[ "$inputInstallPyenv" =~ [yY] ]]; then
            if command -v brew; then
                brew install pyenv
            else 
                print "Whoops! Brew not found bruh."
            fi
        fi
    fi

    if command -v pyenv &> /dev/null; then
        eval "$(pyenv init -)"

        if command -v python &> /dev/null; then
            PYTHON_VERSION_CHECK_STRING="Python $DEFAULT_PYTHON_VERSION"
            if [[ $(python --version 2>&1) =~ $PYTHON_VERSION_CHECK_STRING ]]; then
                print "\t$PYTHON_VERSION_CHECK_STRING is installed and likely the global default."
                print "\tExecute: pyenv install -l | grep \$DEFAULT_PYTHON_VERSION to list available versions"
            else
                print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                print "\t$PYTHON_VERSION_CHECK_STRING is not installed or is not the global default. "
                print "\tExecute: installPython (after checking \'\$DEFAULT_PYTHON_VERSION\' is configured as expected)"
                print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

                print "Listing available python versions around $PYTHON_VERSION_CHECK_STRING."
                pyenv install -l | grep $DEFAULT_PYTHON_VERSION
                print "Listing Done."

                installPython
            fi

            # print "Confirming 'python --version'"
            python --version
        else
            installPython
        fi
    fi

    print "Done."
}

function upgradePip() {
    pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org --upgrade pip
}

function installJQ() {
    print "Install jq? [Y/n]"; read inputInstallJQ;
    if [[ $inputInstallJQ =~ [Yy] ]]; then
        brew update && brew install jq
    fi
}

function installCLIs() {
    print "Install OCI CLI? [Y/n]"; read inputInstallOCICLI;
    if [[ $inputInstallOCICLI =~ [Yy] ]]; then
        brew update && brew install oci-cli

        print "Executing EXPORT OCI_CLI_AUTH='security_token'"
        export OCI_CLI_AUTH='security_token'
        print "Checking OCI_CLI_AUTH: $OCI_CLI_AUTH."
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

function printCertText() {
    # $1 = path to pem file e.g. ./cert.pem
    # -nout omits printing out the encoded version of the private key
    print "Executing: openssl x509 -text -in $1 -noout"
    print '\t$1 = path to pem file e.g. ./cert.pem'
    print '\t-nout omits printing out the encoded version of the private key'
    openssl x509 -text -in $1 -noout
}

function printRemoteCertInfo() {
    # $1 is remote server and port e.g. my-server:8015
    # -nout omits printing out the encoded version of the private key
    print "Executing: openssl s_client -connect $1 | openssl x509 -subject -dates -noout"
    print '\t$1 is remote server and port e.g. my-server:8015'
    print '\t-nout omits printing out the encoded version of the private key'
    openssl s_client -connect $1 | openssl x509 -subject -dates -noout
}

function launchChromeWithInsecureContent() {
    print "Executing cmd: '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --user-data-dir=/tmp/tempchrome --allow-running-insecure-content --incognito &'..."
    /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --user-data-dir=/tmp/tempchrome --allow-running-insecure-content --incognito &
    print "Done."
}

# Yubikey Hepers
# ===================================================================================
export OPENSC_LIB_VERSION="0.23.0"
# What about onepin-opensc-pkcs11.so?
# export OPENSC_PATH='/usr/local/lib/opensc-pkcs11-local.so'
export OPENSC_PATH='/usr/local/lib/opensc-pkcs11.so'

function fixYubiKey() {
    if [[ $1 == "force" ]]; then
        echo "Killing ssh-agent and ssh-pkcs11-helper processes..."
        pkill -9 ssh-agent
        pkill -9 ssh-pkcs11-helper
    else
        echo "Not killing existing processes. Use 'fixYubiKey force' to kill ssh-agent and ssh-pkcs11-helper."
    fi

    # Start Agent
    echo "Starting up ssh-agent..."
    result=$(ssh-agent | grep 'SSH_AUTH_SOCK.*')
    echo $result

    # Expose the process id
    echo "Check variable SSH_AUTH_SOCK...(process ID should match)"
    echo $SSH_AUTH_SOCK

    # Load Yubi keys
    echo "Loading yubi keys..."
    printf "If process IDs match then execute: ssh-add -s /usr/local/lib/opensc-pkcs11.so"
}

function reinitSSHAndOpenSC() {
    print "Geez, you're going with the last resort hey. Good luck!"

    print "If you need to check versions, try brew info|list opensc commands.\n"

    # print "Uninstalling openssh"
    # brew uninstall openssh

    print "\nUninstalling opensc"
    brew uninstall opensc

    # print "\nInstalling openssh..."
    # print "Continue? [y|n]"; read inputContinueInstall;
    # if [[ $inputContinueInstall =~ [Yy] ]] then
    #     brew install openssh
    # fi

    # print "\t NOTE: The OpenSSH PKCS11 smartcard integration will not work from High Sierra onwards. If you need this functionality, unlink this formula, then install the OpenSC cask."
    print "\nInstalling opensc...Continue? [y|n]"; read inputContinueInstall;
    if [[ $inputContinueInstall =~ [Yy] ]] then
        brew install --cask opensc
    fi

    # print "\nRemoving $OPENSC_PATH..."
    # rm -rf $OPENSC_PATH

    # if [[ -f "/usr/local/Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so" ]]; then
    #     print "\nCopying opensc-pkcs11.so from Cellar..."
    #     cp /usr/local/Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so /usr/local/lib/
    #     print "Listing $OPENSC_PATH..."
    #     ll $OPENSC_PATH
    # else
    #     print "\nCouldn't copy file. /usr/local/Cellar/opensc/$OPENSC_LIB_VERSION/lib/opensc-pkcs11.so not found."
    #     print "Listing /usr/local/Cellar/opensc/"
    #     ll /usr/local/Cellar/opensc/
    # fi

    print "\nIf no errors are shown above, you also run reloadOpenSC to get the SC key loaded to your ssh-agent."
    print "Execute reloadOpenSC now? [y|n]"; read inputContinueReload;
    if [[ $inputContinueReload =~ [Yy] ]]; then
        loadSSHKeys
    fi

    print "\nSeeing errors? Well goodluck then. :)"
    print "ssh-agent has a provider path whitelist (see -P option) which by default which include both /usr/lib/* and /usr/local/lib/* ."
    print "Try adding the provider path directly to your ssh config `PKCS11Provider /usr/local/lib/opensc-pkcs11-local.so`. Also check what path any IdentityFile directives are point to."
    print "Try giving this a read: https://github.com/OpenSC/OpenSC/wiki/macOS-Quick-Start."

    print "\nDone."
}

function loadSSHKeys() {
    print "Running ssh-add -l..."
    ssh-add -l

    print "\nCopying ssh-config file from backup..."
    cp $BACKUPS_FOLDER/ssh-config ~/.ssh/config

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
    
    print "\nAdding himesh.ramjee@gmail.com keys..."
    ssh-add ~/.ssh/himesh.ramjee@gmail.com

    print "\nAdding ams keys..."
    ssh-add ~/.ssh/ams_ssh_agent.key

    print "\nConfirm all keys added; running ssh-add -l..."
    ssh-add -l

    print "\nIf you're struggling with 'agent refused' errors then try following...follow debugging steps in 'showYubiKeyCommands'"
}

function showYubiKeyCommands() {
    print "brew install yubico-piv-tool"
    print "Check how many retries attempts you have to guess PIN: \n\tyubico-piv-tool -a status | grep 'PIN'"
    print "Verify PIN (this will use up retry limit - seems I got about ~5 free attempts before the default 15 started counting down): \n\tyubico-piv-tool -a verify -P <PIN>"
    print "Show all slots: \n\tyubico-piv-tool -a status"
    print "Show fingerprint: \n\tpkcs11-tool --read-object --type pubkey --label 'PIV AUTH pubkey'|openssl dgst -md5 -c"
    print "Show certificate: \n\tpkcs11-tool --read-object --type pubkey --label 'PIV AUTH pubkey' 2>/dev/null | openssl rsa -pubin -inform DER -outform PEM 2>/dev/null"
    print "\n**For debugging**\n"
    print "\nStart ssh-agent in debug mode: \n\t/usr/bin/ssh-agent -d"
    print "\n\tLook for and execute line similar to: SSH_AUTH_SOCK=/tmp/foo/agent.sock; export SSH_AUTH_SOCK;"
    print "\n\tThen load the keys: ssh-add -s /usr/local/lib/opensc-pkcs11.so"
}

function setNodeVersion() {
    if [[ -z "$1" ]]; then
        # print "Usage: setNodeVersion [12|14|latest]. If you see an error then verify that the version is actually installed. e.g. 'brew search node'"
        print "Usage: setNodeVersion [12|14|16]. If you see an error then verify that the version is actually installed. e.g. 'nvm ls'"
        return
    fi

    if [[ "$1" =~ "latest" ]]; then
        # brew link --overwrite node
        print "Specify a version"
    else
        # brew link --overwrite node@$1
        nvm use $1
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

function installNVM() {
    # Quick refresher: https://blog.logrocket.com/how-switch-node-js-versions-nvm/
    # Installing NVM though can be problematic
    # Seems the upgrade process doesn't play nice if npm is installed via brew and the alternative is to use NVM only to manage node versions
    # My ideal has been to use a single package manager and installation via brew does work well. See https://collabnix.com/how-to-install-and-configure-nvm-on-mac-os/
    # But as mentioned the paths for brew are '..../Cellar/....' based which doesn't work when trying to upgrade node with something like `npm install -g npm`

    print "\nInstall NVM? [y|n] "; read inputNVMInstall
    if [[ $inputNVMInstall =~ [yY] ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
        print "\nDone - check for errors in above output."

        # Install script does it but let's ensure our local version is still working
        loadNVM

        print "\nListing available versions of node: nvm ls-remote"
        nvm ls-remote

        print "\nListing currently installed node versions: nvm ls"
        nvm ls

        print "\nInstall command: 'nvm install <version>' e.g. 'nvm install 16'"
    fi
}

function loadNVM() {
    print "\nLoading NVM..."
    # print '\nExecuting: export NVM_DIR=$HOME/.nvm'
    export NVM_DIR="$HOME/.nvm"
    print "NVM_DIR = $NVM_DIR"
    
    # print 'Executing: [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm'
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    
    # print 'Executing: [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

    print "Setting Node v14 as default"
    nvm alias default 14
    print "Done."
}

# Package Security
function grypescan() {
    print 'Using registry: '$DOCKER_REGISTRY_URL

    if [[ ! -z "$1" ]]; then
        print 'Scanning package: '$1
        grype registry:$DOCKER_REGISTRY_URL/$1 
    else
        print 'Specify package name.\n'
        print 'Usage: grypescan <package-name>\n'
    fi
}

function showCrowdStrikeCommands() {
    print "Check sensor is running: sudo /Applications/Falcon.app/Contents/Resources/falconctl stats"
    print "Start the sensor: sudo /Applications/Falcon.app/Contents/Resources/falconctl load"
}

# Aliases
# =================================================================================================

# Brew
loadBrew

# Local OS
alias ll='ls -hal'

# Agents
alias reload-cs='sudo /Applications/Falcon.app/Contents/Resources/falconctl load && echo "\n==========\nNow retry VPN connection\n==========\n"'

# Yubikey
alias loadyubikey='ssh-add -s /usr/local/lib/opensc-pkcs11.so'
alias refresh-yubikey='pkill -9 ssh-agent;pkill -9 ssh-pkcs11-helper; ssh-add -s /usr/local/lib/opensc-pkcs11-local.so'
alias refresh-onepinyubikey='pkill -9 ssh-agent;pkill -9 ssh-pkcs11-helper; ssh-add -s /usr/local/lib/onepin-opensc-pkcs11.so'

# Setup CLI
if ! command -v jq &> /dev/null; then
    installJQ
fi

# Python initialization
setupPyenv

# Setup Java
setJavaHome 17

# Setup Node
if command -v nvm &> /dev/null; then
    loadNVM
else
    print "\nNVM not found. Run installNVM"
fi

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
alias kubectl-pd="kubectl get pods -o json | jq '.items | group_by(.spec.nodeName)[][] | [.spec.nodeName, .metadata.name] | @csv' --raw-output"

# Maven

# Rancher
alias rdocker="$HOME_DIRECTORY/.rd/bin/docker"

# Git
alias gfp="git fetch && git pull"
alias testGitSSH="ssh -T git@github.com"
# alias getLastCommit="${git log | head -n 1 | awk '{print $2}'}"
alias getLastCommit="git log -1 --pretty=format:'%H'"

# print '\n$PATH: '$PATH
# print "========================================\n";
GRAPHVIZ_PATH='/usr/local/bin/dot'
export GRAPHVIZ_DOT="$GRAPHVIZ_PATH"
export PATH="$PATH:$HOME_DIRECTORY/.rd/bin:$GRAPHVIZ_PATH"

# SQL
export PATH="$PATH:/usr/local/Caskroom/sqlcl/24.1.0.087.0929/sqlcl/bin"

print "\n=======================================================================================";
print "Additional scripts"
print "Script directory: $BACKUPS_FOLDER/local-only-scripts/"
print "=========================================================================================\n";

localScripts=("local-only-all.sh" "local-only-oci.sh" "local-only-ohai.sh")
# ${localScripts[@]} -> Values
# ${!localScripts[@]} -> Indices
for localScript in ${localScripts[@]}; do
    print "Sourcing $localScript"
    source $BACKUPS_FOLDER/local-only-scripts/$localScript
    print "Done.\n"
done
