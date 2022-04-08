FROM elixir:1.13

RUN apt-get update && \
    apt-get install -y \
    postgresql-client inotify-tools 

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential xorg libssl-dev libxrender-dev wget gdebi xvfb \
    wkhtmltopdf
# Install wkhtml to pdf
RUN echo "xvfb-run -a -s \"-screen 0 640x480x16\" wkhtmltopdf \"\$@\"" >/usr/local/bin/wkhtmltopdf-wrapper && chmod +x /usr/local/bin/wkhtmltopdf-wrapper
WORKDIR /app
COPY . /app
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get
RUN mix do compile
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# ENV PORT 4000
CMD ["bash", "/app/entrypoint.sh"]