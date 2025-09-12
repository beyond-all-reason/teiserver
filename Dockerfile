# This file is modeled after https://hexdocs.pm/phoenix/releases.html#containers
# and the build script from teiserver repo.
#
# This file is written in a way that tries to optimize caching of the build steps
# as much as possible. It is increasing the complexity of the file a bit.
#
# The image can be built with the following command from the teiserver repo root:
#
#   sudo podman build -t teiserver -f .
#
# The release is copied and placed in the filesystem of the host, but it could be
# also run as a container with something like:
#
#   sudo podman run --rm -it \
#       --network=host \
#       -v /etc/ssl/certs/teiserver.crt:/etc/ssl/certs/teiserver.crt:ro \
#       -v /etc/ssl/certs/teiserver_full.crt:/etc/ssl/certs/teiserver_full.crt:ro \
#       -v /etc/ssl/private/teiserver.key:/etc/ssl/private/teiserver.key:ro \
#       -v /etc/ssl/dhparam.pem:/etc/ssl/dhparam.pem:ro \
#       teiserver
#

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=26.2.5.14
ARG DEBIAN_VERSION=trixie-20250811
ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}-slim"

FROM ${BUILDER_IMAGE} as builder

RUN apt-get update \
 && apt-get install --no-install-recommends --yes git make build-essential \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force \
 && mix local.rebar --force

RUN mkdir /build
WORKDIR /build

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
{# This is a hack to force disable discord integration, there is not any other
 # way to do it in config... and that's not the worst part...
 # https://github.com/beyond-all-reason/teiserver/issues/237
 #}
{% if not teiserver_discord_integration %}
RUN sed -i -E 's/:nostrum(.*)runtime:.*/:nostrum\1runtime: false}/' mix.exs
{% endif %}
RUN mix deps.get

RUN mkdir config
COPY config/config.exs config/

# Need to also compiled dev to be able to compile static assets...
COPY config/dev.exs config/
RUN MIX_ENV=dev mix deps.compile

# Now time to compile dependencies for prod.
# We touch empty secrets and compile to avoid recompiling when the secrets
# are changed. This assumes that the secrets don't impact the compilation
# of the project dependencies.
COPY config/prod.exs config/
RUN touch config/prod.secret.exs
RUN mix deps.compile

COPY priv priv
COPY assets assets
# The assets compilation works only in dev environment but files are needed for
# the prod one... https://github.com/beyond-all-reason/teiserver/issues/238
RUN MIX_ENV=dev mix assets.deploy

# Compile for prod
COPY lib lib
# This should really not be here
# https://github.com/beyond-all-reason/teiserver/issues/236
COPY config/prod.secret.exs config/
RUN mix compile

# Create release files
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update \
 && apt-get install --no-install-recommends --yes libstdc++6 openssl libncurses6 locales tini \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
ENV MIX_ENV="prod"

COPY --from=builder /build/_build/${MIX_ENV}/rel/teiserver  ./
RUN mkdir src
COPY --from=builder /build/config/prod.secret.exs src/prod.secret.exs

ENTRYPOINT ["tini", "--"]
CMD /app/bin/teiserver start
