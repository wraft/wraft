ARG ELIXIR_VERSION=1.19.0
ARG OTP_VERSION=26.2.2
ARG DEBIAN_VERSION=bookworm-20251117

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y \
    && apt-get install -y curl build-essential git openjdk-17-jdk \
       ca-certificates libssl-dev openssl \
    && update-ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain for Rustler
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ARG SECRET_KEY_BASE
ARG SELF_HOSTED
ARG DATABASE_URL
ENV MIX_ENV="prod"
ENV RELEASE_NAME="wraft_doc"
ENV PORT=4000

COPY mix.exs mix.lock ./
RUN mix deps.clean jido_ai --unlock || true
RUN HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120 mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets
COPY native native

RUN mix assets.deploy
RUN mix compile
COPY config/runtime.exs config/
COPY rel rel
RUN mix release


FROM ${RUNNER_IMAGE}

# Install system dependencies
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
    ghostscript \
    curl \
    ca-certificates \
    openjdk-17-jdk && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Fix ImageMagick PDF security policy
RUN sed -i 's/<policy domain="coder" rights="none" pattern="PDF" \/>/<policy domain="coder" rights="read|write" pattern="PDF" \/>/' /etc/ImageMagick-6/policy.xml

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

# Install Typst (architecture-aware)
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
        amd64) TYPST_ARCH=x86_64-unknown-linux-musl ;; \
        arm64) TYPST_ARCH=aarch64-unknown-linux-musl ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    wget -q https://github.com/typst/typst/releases/download/v0.13.0/typst-${TYPST_ARCH}.tar.xz && \
    tar -xf typst-${TYPST_ARCH}.tar.xz && \
    mv typst-${TYPST_ARCH}/typst /usr/local/bin/typst && \
    rm -rf typst-${TYPST_ARCH} typst-${TYPST_ARCH}.tar.xz

# Set locale
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV MIX_ENV="prod"

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Install eforms.sty, insdljs.sty, exerquiz.sty, taborder.sty and required .def files
WORKDIR /tmp/acrotex
RUN wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/eforms.dtx && \
    wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/eforms.ins && \
    latex eforms.ins && \
    \
    wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/insdljs.dtx && \
    wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/insdljs.ins && \
    latex insdljs.ins && \
    \
    wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/exerquiz.dtx && \
    wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/exerquiz.ins && \
    latex exerquiz.ins && \
    \
    wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/taborder.dtx && \
    wget https://mirrors.ctan.org/macros/latex/contrib/acrotex/taborder.ins && \
    latex taborder.ins && \
    \
    mkdir -p /usr/local/share/texmf/tex/latex/acrotex && \
    mv eforms.sty insdljs.sty exerquiz.sty taborder.sty \
    *.def *.dtx /usr/local/share/texmf/tex/latex/acrotex/ && \
    \
    mktexlsr && \
    kpsewhich eforms.sty && \
    kpsewhich insdljs.sty && \
    kpsewhich exerquiz.sty && \
    kpsewhich taborder.sty

# App directories + user setup
WORKDIR /app
RUN useradd -u 1000 -M -s /bin/sh -d /app wraftuser

# Only copy the final release
COPY --from=builder /app/_build/${MIX_ENV}/rel/wraft_doc ./
COPY priv ./priv

RUN java -version
RUN test -f priv/visual-signer-v2-1.0-SNAPSHOT-jar-with-dependencies.jar && echo "JAR file found" || echo "JAR file not found"

COPY ./entrypoint.sh /entrypoint.sh
COPY rel/commands/migrate.sh /app/
COPY rel/commands/rollback.sh /app/
COPY rel/overlays/seeds.sh /app/
COPY priv/pandoc_filters/*.lua /app/priv/pandoc_filters/

RUN chmod a+x /app/priv/pandoc_filters/*.lua
RUN chmod a+x /entrypoint.sh /app/migrate.sh /app/seeds.sh
RUN chown -R wraftuser:wraftuser /app
USER wraftuser

WORKDIR /app
ENV LISTEN_IP=0.0.0.0
EXPOSE ${PORT}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["run"]
