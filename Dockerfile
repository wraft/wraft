ARG ELIXIR_VERSION=1.15.8
ARG OTP_VERSION=25.2.3
ARG DEBIAN_VERSION=bookworm-20240722

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"


FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y \
  && apt-get install curl -y \
  && apt-get install -y build-essential git \
  && apt-get clean \
  && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ARG SECRET_KEY_BASE
ARG SELF_HOSTED
ARG DATABASE_URL
ENV MIX_ENV="prod"
ENV RELEASE_NAME="wraft_doc"
ENV PORT=4000

# install mix dependencies
COPY mix.exs mix.lock ./
RUN HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120 mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

COPY priv ./priv
COPY lib ./lib


# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

# RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
#   && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN apt-get update && \
    apt-get install -y \
    postgresql-client inotify-tools

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential xorg libssl-dev libxrender-dev git wget vim gdebi xvfb gcc libstdc++6 \
    locales \
    wkhtmltopdf \
    pandoc \
    texlive-fonts-recommended \
    texlive-plain-generic \
    texlive-latex-extra \
    texlive-xetex


# Set the locale
# RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"

# set runner ENV
ENV MIX_ENV="prod"

RUN useradd -u 1000 -M -s /bin/sh -d /app wraftuser
# Only copy the final release from the build stage
COPY --from=builder /app/_build/${MIX_ENV}/rel/wraft_doc ./

COPY priv ./app/priv


COPY ./entrypoint.sh /entrypoint.sh

COPY rel/commands/migrate.sh /app/
COPY rel/overlays/seeds.sh /app/

RUN chmod a+x /entrypoint.sh
RUN chmod a+x /app/migrate.sh
RUN chmod a+x /app/seeds.sh
RUN chown -R wraftuser:wraftuser /app
USER wraftuser

WORKDIR /app
ENV LISTEN_IP=0.0.0.0
EXPOSE ${PORT}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["run"]
