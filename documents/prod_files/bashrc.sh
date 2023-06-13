# Teiserver
alias nginxlog='sudo grc tail /var/log/nginx/error.log -n 60 -f'
alias sitelog='grc --config=elixir.log tail -f /var/log/central/error.log -n 60'
alias siteinfo='grc --config=elixir.log tail -f /var/log/central/info.log -n 60'
alias dodeploy='sudo sh /scripts/deploy.sh'

alias catsiteinfo='cat /var/log/central/info.log'
alias centralapp='sh /apps/central/bin/central'

alias stable_deploy='sudo sh /scripts/stable_deploy.sh'
alias preparedeploy='sudo sh /scripts/prepare_deploy.sh'
alias quickrestart='sudo sh /scripts/quick_restart.sh'

alias postgreslog='sudo cat /var/log/postgresql/postgresql-15-main.log'

export PATH
