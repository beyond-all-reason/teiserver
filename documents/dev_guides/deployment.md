If you've not already setup your server you might want to check out [documents/dev_guides/production_setup_linux.md](/documents/dev_guides/production_setup_linux.md).

### Requirements
- A production server setup
- Locally running Elixir
- Docker installed on your computer

### prod.secret.exs
`config/prod.secret.exs` is ignored in the gitignore for obvious reasons. This means you will need to create your own one. Luckily I [made a template for you](/documents/prod/example_prod_secret.exs).

#### Dockerfile
```
FROM elixir:1.11.2
ARG env=dev
ENV LANG=en_US.UTF-8 \
   TERM=xterm \
   MIX_ENV=$env
WORKDIR /opt/build
ADD ./bin/build ./bin/build
CMD ["bin/build"]
```

#### Deploy script
```
#!/usr/bin/env bash
touch lib/central_web/views/admin/general_view.ex
sh scripts/build_container.sh
sh scripts/generate_release.sh

scp -i ~/.ssh/id_rsa rel/artifacts/teiserver.tar.gz deploy@yourdomain.com:/releases/teiserver.tar.gz

mix phx.digest.clean --all

echo "ssh into your server and run dodeploy"
```

#### scripts/build_container.sh
```
#!/usr/bin/env bash
# This is called from bin/deploy, you should not need to call it manually

docker build --build-arg env=prod \
 --build-arg env=prod \
 -t teiserver:latest .
```

#### scripts/generate_release.sh
```
#!/usr/bin/env bash
docker run -v $(pwd):/opt/build --rm -it teiserver:latest /opt/build/bin/build
```