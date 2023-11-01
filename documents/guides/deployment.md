If you've not already setup your server you might want to check out [documents/guides/production_setup_linux.md](/documents/guides/production_setup_linux.md).

### Requirements
- A production server setup
- Locally running Elixir
- Docker installed on your computer

### prod.secret.exs
`config/prod.secret.exs` is ignored in the gitignore for obvious reasons. This means you will need to create your own one. Luckily I [made a template for you](/documents/prod_files/example_prod_secret.exs).

#### Dockerfile
A docker file is included in the repo but within [documents/prod_files](documents/prod_files) are other docker images providing more control over the building of your image and might be of interest.

#### Deploy script
```
#!/usr/bin/env bash
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