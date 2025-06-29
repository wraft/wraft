ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=25.0.4
ARG DEBIAN_VERSION=bookworm-20250520

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"


FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y \
  && apt-get install -y curl build-essential git openjdk-17-jdk \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain for Rustler
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

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
# Clean jido_ai dependency before getting dependencies
RUN mix deps.clean jido_ai --unlock || true
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
COPY native native

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release


# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

# Install required system dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    postgresql-client \
    inotify-tools \
    build-essential \
    xorg \
    libssl-dev \
    libxrender-dev \
    lmodern \
    git \
    wget \
    vim \
    gdebi \
    xvfb \
    gcc \
    libstdc++6 \
    locales \
    wkhtmltopdf \
    texlive-fonts-recommended \
    texlive-plain-generic \
    texlive-latex-extra \
    texlive-xetex \
    imagemagick \
    curl \
    ca-certificates \
    openjdk-17-jdk && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Pandoc
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
        amd64) PANDOC_DEB=pandoc-3.6.3-1-amd64.deb ;; \
        arm64) PANDOC_DEB=pandoc-3.6.3-1-arm64.deb ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    wget -q https://github.com/jgm/pandoc/releases/download/3.6.3/${PANDOC_DEB} && \
    dpkg -i ${PANDOC_DEB} && \
    rm -f ${PANDOC_DEB}

# Install Typst
RUN wget -q https://github.com/typst/typst/releases/download/v0.13.0/typst-x86_64-unknown-linux-musl.tar.xz && \
    tar -xf typst-x86_64-unknown-linux-musl.tar.xz && \
    mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/typst && \
    rm -rf typst-x86_64-unknown-linux-musl typst-x86_64-unknown-linux-musl.tar.xz

# Set the locale
# RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV MIX_ENV="prod"

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

WORKDIR "/app"

RUN useradd -u 1000 -M -s /bin/sh -d /app wraftuser
# Only copy the final release from the build stage
COPY --from=builder /app/_build/${MIX_ENV}/rel/wraft_doc ./

# Copy priv directory with JAR file
COPY priv ./priv

# Verify Java installation and JAR file
RUN java -version
RUN test -f priv/visual-signer-v2-1.0-SNAPSHOT-jar-with-dependencies.jar && echo "JAR file found" || echo "JAR file not found"

COPY ./entrypoint.sh /entrypoint.sh

COPY rel/commands/migrate.sh /app/
COPY rel/overlays/seeds.sh /app/

COPY priv/pandoc_filters/*.lua /app/priv/pandoc_filters/
RUN chmod a+x /app/priv/pandoc_filters/*.lua

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
