#!/bin/bash

# PATH updates
export PATH="/usr/local/bin:/usr/bin/git:/usr/bin:/usr/local/sbin:$PATH"
export PATH=/Users/himeshramjee/Library/Python/3.7/bin/:$PATH

AWS_ACCOUNT_NUMBER=

# Local OS
alias ll='ls -hal'

# Environment Variables
export JAVA_HOME=/Library/Java/JavaVirtualMachines/amazon-corretto-11.jdk/Contents/Home

# Python
alias py3='/Users/himeshramjee/.pyenv/shims/python' # Temporary. Fix via https://opensource.com/article/19/5/python-3-default-mac
alias pip='/Users/himeshramjee/.pyenv/shims/pip' # Temporary. Fix via https://opensource.com/article/19/5/python-3-default-mac

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

# Remote server management
alias gonxs='ssh -i ~/.ssh/LightsailDefaultKey-eu-west-1.pem ubuntu@'

print "~/.bash_profile processed."
