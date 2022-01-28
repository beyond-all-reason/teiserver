# Teiserver
alias nginxlog='sudo grc tail /var/log/nginx/error.log -n 40 -f'
alias sitelog='grc --config=elixir.log tail -f /var/log/central/error.log -n 40'
alias siteinfo='grc --config=elixir.log tail -f /var/log/central/info.log -n 40'
alias dodeploy='sudo sh /scripts/deploy.sh'
alias quickrestart='sudo sh /scripts/quick_restart.sh'

PATH=$PATH:/usr/lib/postgresql/12/bin
PATH=$PATH:$HOME/bin

export PATH
