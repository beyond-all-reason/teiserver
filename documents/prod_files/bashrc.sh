# Teiserver
alias nginxlog='sudo grc tail /var/log/nginx/error.log -n 60 -f'
alias siteloggrc='grc --config=elixir.log tail -f /var/log/central/error.log -n 60'
alias sitelogtail='tail -f /var/log/central/error.log -n 60'
alias siteinfogrc='grc --config=elixir.log tail -f /var/log/central/info.log -n 60'
alias siteinfotail='tail -f /var/log/central/info.log -n 60'
alias centralapp='sh /apps/central/bin/central'
alias dodeploy='sudo sh /scripts/deploy.sh'
alias stable_deploy='sudo sh /scripts/stable_deploy.sh'
alias preparedeploy='sudo sh /scripts/prepare_deploy.sh'
alias quickrestart='sudo sh /scripts/quick_restart.sh'

export PATH
