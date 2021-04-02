# Teiserver
alias nginxlog='sudo tail /var/log/nginx/error.log -n 40 -f'
alias sitelog='tail /var/log/central/error.log -n 40 -f'
alias siteinfo='tail /var/log/central/info.log -n 40 -f'
alias dodeploy='sudo sh /scripts/deploy.sh'
alias quickrestart='sudo sh /scripts/quick_restart.sh'

PATH=$PATH:/usr/lib/postgresql/12/bin
PATH=$PATH:$HOME/bin

export PATH
