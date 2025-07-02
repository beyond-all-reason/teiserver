FROM hexpm/elixir:1.18.2-erlang-26.2.5.2-debian-buster-20240612-slim

# Install build tools
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=dev

# Fetch Hex/Rebar and deps
COPY mix.exs mix.lock ./
RUN mix local.hex --force \
  && mix local.rebar --force \
  && mix deps.get \
  && mix sass.install

# Copy source & compile
COPY . .
RUN mix deps.compile \
  && mix compile

EXPOSE 4000
CMD ["mix", "phx.server"]