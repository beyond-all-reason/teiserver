### Requirements
- Install Docker
  - For development machines, [Docker Desktop](https://docs.docker.com/engine/install/#desktop) (Linux, Mac, Windows) works well
    - For Linux Development Machines, a lightweight solution (without the Desktop GUI, etc, etc.) is to use the production solution 👇
  - For production use-cases, use [Docker Engine](https://docs.docker.com/engine/install/#server)
    - You may need to enable BuildKit in `/etc/docker/daemon.json`, see [the documentation](https://docs.docker.com/build/buildkit/#getting-started)
- The helper scripts below assume a "generic GNU/Linux environment" with the various tools that entails

## Docker Compose
In the root of this repository are docker compose files that allow creating development and production
"deployments" of teiserver, with it's required PostgreSQL DB and Nginx reverse proxy.

These various workflows are designed to abstract away the majority of the manual effort in running teiserver. Be it credentials, 
creating TLS certificates, building a PostgreSQL database, replicating production environments, etc.. The provided 
docker composes also provide portability because of their abstraction from the host OS. You can equally use these 
compose formulas documented below on Windows, Mac, and Linux.

For most users, you should only ever need to use the two docker compose workflows; Development and Production.

For tips & tricks, frequently asked questions, etc. See the [FAQ](#faq)

### Development Usage

```bash
bash scripts/dev_compose.sh
```

<details>
  <summary>Script Details:</summary>

- Creates various dynamically generated secrets for development located at `$REPO_ROOT/runtime/dev`.
  These secrets include TLS certificate(s) for Nginx and `teiserver`, database users, passwords, etc.
  There is no need for you to edit these secrets. This will generate TLS certificates and Diffie Hellman parameters
  for TLS. These credentials (because it's a development environment) are not rotated upon repeated deployments
- Issue the command to docker to build the various containers (Nginx, PostgreSQL, teiserver)
- Run the containers (when any of their dependent components are healthy and ready to accept connections)
- Mount all the local development directories and files within the repository into the container.
- Automatically display all logs from all the containerized components
- Upon exiting, stop the docker compose deployment (so it's not just silently continuing to run in the background)
</details>

### Production Usage

```bash
bash scripts/prod_compose.sh
```

Reminder(s): 
- This will *not* start prod. It only generates secrets and tells you the command you have to run to start prod.
- You should only need to do this *once* on a production server. After that, you should only need to update specific
  containers, as detailed in the output of the above script
- You *will* need to modify some of the config in `$REPO_ROOT/runtime/prod` after executing the above command
  (such as symlinking, or copying over, your LetsEncrypt CertBot certificates into `$REPO_ROOT/runtime/prod/tls`)

<details>
  <summary>Script Details:</summary>

- Does pretty much the same thing that the development workflow does, but guarantees that each time you run this command,
  many of the credentials used between services are automatically changed and rotated.
- Does *not* mount any local directories into the container(s). The container(s) is isolated from your local environment
- Finally the script prints out general commands you'll use to create, delete, and update the production deployment
</details>

### FAQ
<details>
  <summary>Show</summary>

- I'm trying to run `iex` on teiserver.
  - Open a shell to the teiserver container (a lot like ssh without creds) `docker exec -it teiserver-teiserver-1 /bin/bash`
  - Run `iex` like you normally would
- I want to "hot-reload" a module in development `teiserver`
  - Open a shell like you would for the question above. Since the development version of teiserver container has all of
    your local development directories mounted, and `teiserver` in development is started with `mix phx.server`, you
    can simply `iex` the server and reload the relevant modules to your hearts content.
  - Alternatively, if you can simply restart the `teiserver` container: `docker restart teiserver-teiserver-1` which
    will just "rerun" `mix phx.server`
- How do I know what containers are and are not running?
  - `docker ps` will show you what is running, or trying to run. For this repo's docker-compose, it will also tell you
    if individual components are healthy or not.
  - `docker ps -a` will show stopped containers
- I only want to see a specific containers logs.
  - `docker logs CONTAINER-NAME` (add -f to "follow" logs)
- I'm trying to understand resource utilization (I wanna run htop)
  - You shouldn't need to do this in the container. Containers are not VM's, so you can do this on your host and see everything and more :>
  - Note that some Docker Desktop deployments, such as the one for Mac and Windows, utilize a VM to run the Docker Engine.
    So this method will not work for those types of platforms. Easiest thing to do would be to pop a shell in the 
    specific container and install the relevant tools at runtime.
- I want to connect to the database and run SQL queries manually
  - The easiest way would be to pop a shell within the PostgreSQL container like you do for teiserver; `docker exec -it teiserver-postgresql-1 /bin/bash`
  - Run `psql` to access the DB. You can find the credentials and users within `runtime/` for your specific env, *or* 
    look at the environment variables within the PostgreSQL container.
- I want to migrate PostgreSQL databases between some PostgreSQL database I have and the containerized DB.
  - I would recommend using SSH local port forwarding to port-forward the various required ports between the 
    various hosts. SSH local port forwarding will allow you to bypass a lot of the segmentation built into this 
    by design.
  - Then once you've got the ports "in-range" to communicate with each other, do a normal PostgreSQL migration :>
</details>
