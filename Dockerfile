FROM hexpm/elixir:1.13.0-erlang-24.0.5-ubuntu-focal-20210325

RUN apt-get update && \
    apt-get install -y \
    postgresql-client inotify-tools 

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential xorg libssl-dev libxrender-dev git wget gdebi xvfb \
    # Install wkhtml to pdf
    wkhtmltopdf \
    # Install pandoc
    pandoc \
    # Install latex
    # texlive-latex-base \
    # texlive-latex-recommended \
    # texlive-pictures \
    # texlive \
    texlive-fonts-recommended \
    texlive-plain-generic \
    texlive-latex-extra \
    texlive-xetex


RUN echo "xvfb-run -a -s \"-screen 0 640x480x16\" wkhtmltopdf \"\$@\"" >/usr/local/bin/wkhtmltopdf-wrapper && chmod +x /usr/local/bin/wkhtmltopdf-wrapper
WORKDIR /app
COPY config /app/config
COPY lib /app/lib
COPY mix.exs mix.lock /app/
COPY priv priv
COPY assets assets
COPY entrypoint.sh /app/

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get
RUN mix do compile

CMD ["bash", "/app/entrypoint.sh"]