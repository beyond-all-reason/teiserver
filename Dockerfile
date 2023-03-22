ARG MIX_ENV=prod
ARG FA_RELEASE=6.3.0

FROM elixir:1.14 as build
ARG MIX_ENV
ARG FA_RELEASE
ENV MIX_ENV=${MIX_ENV} \
    FA_RELEASE=${FA_RELEASE} \
    LANG=en_US.UTF-8 \
    TERM=xterm
RUN mkdir /build
WORKDIR /build
COPY mix.exs mix.lock ./
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN touch config/${MIX_ENV}.secret.exs
RUN mix local.rebar --force && \
    mix local.hex --if-missing --force
RUN mix deps.get
RUN mix deps.compile

## This is certaintly a shim, because I don't know where to properly in the build pipeline inject unit testing...
## So we just do them after we'e built a release image :eyes:
FROM build as test
RUN mix test

## Expecting docker compose to mount a lot of directories for this target
FROM build as dev
ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}
VOLUME /var/log
RUN --mount=type=cache,target=/var/cache/apt \
    apt update && \
    apt install -y inotify-tools
COPY . .
CMD /bin/bash -c 'mix phx.server'

FROM dev as prod-build
## This is a shim to compile SASS, assemble assets, etc. that hopefully get picked up by `mix release`
ENV MIX_ENV=dev
RUN --mount=type=cache,target=/build/tmp cd tmp && \
    if [ ! -f fa.zip ]; then \
      curl -LSs https://use.fontawesome.com/releases/v${FA_RELEASE}/fontawesome-free-${FA_RELEASE}-web.zip -o tmp/fa.zip; \
      unzip fa.zip; \
    fi && \
    cp fontawesome-*/css/all.min.css ../priv/static/css/fontawesome.css && \
    cp -R fontawesome-*/webfonts ../priv/static/webfonts
RUN mix sass.install
RUN mix assets.deploy
ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}
RUN mix release

## Supporting non-docker workflows
FROM alpine:latest as output
ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}
COPY --from=prod-build /build/_build /opt/build/_build
CMD mkdir -p /mnt/rel/artifacts && tar -zcf /mnt/rel/artifacts/teiserver.tar.gz /opt/build/_build/prod

FROM elixir:1.14 as prod
ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}
COPY --from=prod-build /build/_build /app/_build
COPY --from=prod-build /build/config/container_${MIX_ENV}.exs /app/_build/${MIX_ENV}/rel/central/releases/0.1.0/runtime.exs
CMD /bin/bash -c '/app/_build/$MIX_ENV/rel/central/bin/central start'
