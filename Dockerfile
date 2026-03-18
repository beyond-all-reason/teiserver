# This file is modeled after https://hexdocs.pm/phoenix/releases.html#containers
# and the build script from teiserver repo.
#
# This file is written in a way that tries to optimize caching of the build steps
# as much as possible. It is increasing the complexity of the file a bit.
#
# The production image can be built with the following command from the teiserver repo root:
#
#   podman build --target runner -t teiserver -f .
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
# Development image (used by docker-compose.yml):
#   podman build --target dev -t teiserver-dev .

ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=26.2.5.1
ARG DEBIAN_VERSION=trixie-20251208
ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}-slim"

# ============================================================
# base — shared foundation for builder and dev stages
# ============================================================
FROM ${BUILDER_IMAGE} AS base

RUN apt-get update \
 && apt-get install --no-install-recommends --yes git make build-essential \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force \
 && mix local.rebar --force

RUN mkdir /build
WORKDIR /build

COPY mix.exs mix.lock ./
RUN mix deps.get

# ============================================================
# builder — compiles and assembles the production release
# ============================================================
FROM base AS builder

ENV MIX_ENV="prod"

RUN mkdir config
COPY config/config.exs config/

# Need to also compile dev to be able to compile static assets...
COPY config/dev.exs config/
RUN MIX_ENV=dev mix deps.compile

# Now time to compile dependencies for prod.
COPY config/prod.exs config/
RUN mix deps.compile

COPY priv priv
COPY assets assets
# The assets compilation works only in dev environment but files are needed for
# the prod one... https://github.com/beyond-all-reason/teiserver/issues/238
RUN MIX_ENV=dev mix assets.deploy

# Compile for prod
COPY lib lib
RUN mix compile

# Create release files
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ============================================================
# dev — hot-reload development container
# ============================================================
FROM base AS dev

RUN apt-get update \
 && apt-get install --no-install-recommends --yes \
    curl \
    inotify-tools \
    postgresql-client \
    geoip-bin \
    geoip-database \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=dev

RUN mix deps.compile

# dart_sass downloads a standalone Dart Sass binary on first use; install it
# here so it is baked into the image rather than fetched at container startup.
RUN mix sass.install

COPY mise.toml /build/
COPY *.exs /build/
COPY *.json /build/
COPY *.yaml /build/

COPY assets /build/assets
COPY bin /build/bin
COPY config /build/config
COPY lib /build/lib
COPY misc /build/misc
COPY priv /build/priv
COPY rel /build/rel
COPY scripts /build/scripts
COPY test /build/test

RUN mix credo --strict || true
RUN mix format
RUN mix compile

COPY docker/teiserver/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["iex", "-S", "mix", "phx.server"]

# ============================================================
# runner — minimal production runtime image, last stage is the default output
# ============================================================
FROM ${RUNNER_IMAGE} AS runner

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

COPY --from=builder /build/_build/${MIX_ENV}/rel/teiserver ./

ENTRYPOINT ["tini", "--"]
CMD /app/bin/teiserver start
