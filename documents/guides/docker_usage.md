# Installation steps
Tested on Ubuntu 24.04

## Install Docker Engine
    `# Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    
    
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    `

## Clone the project

 `
    git clone https://github.com/beyond-all-reason/teiserver.git
    cd teiserver
 `

 ## Build the Dockerfile app

`
    sudo docker build .
`

## Build PostgreSQL file

`
    # 1. Start Postgres in the background
    sudo docker compose up -d db

    # 2. Create & migrate your dev database
    sudo docker compose run --rm app mix ecto.create ecto.migrate

`
## Fake Data
`
    sudo docker compose run --rm app mix teiserver.fakedata

    sudo docker compose up -d app
`

You can now login with the email 'root@localhost' and password 'password'
A one-time link has been created: http://localhost:4000/one_time_login/fakedata_code