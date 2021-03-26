print "\n========================================";
print "Checking local environment setup...";
print "Current Shell is $(echo $SHELL)"
printf '\e[8;40;230t';

NOW_DATE=$(date +"%F")

function resetTerminalConfig() {
    # FIXME: Cleanup with error handling

    LOCAL_SCRIPT_LOCATION="~/.zshrc"

    # Backup current file
    if [ -f "$LOCAL_SCRIPT_LOCATION" ] 
        then
            mv $LOCAL_SCRIPT_LOCATION $LOCAL_SCRIPT_LOCATION-$NOW_DATE.bak
            print "Local script is backed up. Listing directory to surface any cleanup."
            ls -hal ~/
        else
            print "$LOCAL_SCRIPT_LOCATION doesn't exist. No need to backup."
    fi
    
    # Fetch latest script
    curl -L https://raw.githubusercontent.com/himeshramjee/Chaiwala-Developer-Space/master/bash_profile > $LOCAL_SCRIPT_LOCATION
    print "\nLocal config updated."

    print "Attempting to apply it..."
    source $LOCAL_SCRIPT_LOCATION
    print "Terminal reset done. Check for any errors."
}

function getHomebrewInstaller() {
    # FIXME: Cleanup with error handling
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    print "Homebrew download is done (check for errors before executing the install.sh file)."
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
    DEFAULT_PYTHON_VERSION="3.7.3"
    PYTHON_VERSION_CHECK_STRING="Python $DEFAULT_PYTHON_VERSION"
    if [[ $(python --version 2>&1) =~ $PYTHON_VERSION_CHECK_STRING ]]
        then
            print "$PYTHON_VERSION_CHECK_STRING is installed."
            return 0
        else
            print "$PYTHON_VERSION_CHECK_STRING is missing. Continuing with python setup now."

            print "What version of python do you want to install? Hit enter to install $DEFAULT_PYTHON_VERSION or specify a new version."; read inputPythonVersion
            if [ -z $inputPythonVersion ]
                then
                    inputPythonVersion=$DEFAULT_PYTHON_VERSION
            fi

            pyenv install $inputPythonVersion

            print "Pyenv installation is done. Setting version $inputPythonVersion as default."
            pyenv global $inputPythonVersion
    fi

    python --version
}

function configureLocalProxies() {
    HTTP_PROXY=http://www-proxy-lon.uk.oracle.com:80
    HTTPS_PROXY=$HTTP_PROXY
    NO_PROXY_LIST=localhost,127.0.0.1,oraclecorp.com,ucfc2z3c.usdv1.oraclecloud.com,10.241.160.84,oc-test.com
    alias proxyon='export http_proxy=$HTTP_PROXY; export https_proxy=$HTTPS_PROXY; export HTTP_PROXY; export HTTPS_PROXY; export no_proxy=$NO_PROXY_LIST; export NO_PROXY=$NO_PROXY_LIST'
    alias proxyoff='unset http_proxy && unset https_proxy && unset HTTP_PROXY && unset HTTPS_PROXY && unset no_proxy && unset NO_PROXY_LIST'
    print "Local proxy config is done."
}

# Local OS
alias ll='ls -hal'

# Local Environment setup
configureLocalProxies

# Python initialization
setupPython

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

print "========================================\n";
