# === Build stage ===
ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20260112-slim
ARG NODE_VERSION=20

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ARG NODE_VERSION

RUN apt-get update -y && \
    apt-get install -y build-essential git curl && \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN npm install --prefix assets
RUN mix assets.setup
RUN mix assets.deploy

RUN mix compile

# Copy runtime config last so earlier layers are cached
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# === Runtime stage ===
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

RUN chown nobody /app
ENV MIX_ENV=prod

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/craftplan ./

USER nobody

CMD ["bin/server"]
