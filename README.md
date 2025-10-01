<div align="center">
  <svg width="174" height="56" viewBox="0 0 116 37" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_2599_1170)">
      <path d="M39.52 23.5101L39.3 25.1301H39.05L38.79 23.5101L35.43 10.2201H30.49L27.16 23.4701L26.95 24.6201L26.7 24.5701L26.57 23.5101L23.89 10.2201H17.84L23.25 31.5201H29.76L32.83 19.8901H33.08L36.15 31.5201H42.97L48.42 10.2201H42.33L39.52 23.5101ZM58.08 12.4401L57.83 12.3501V10.2201H51.91V31.5601H57.83V17.1201C59.1096 15.9213 60.7966 15.2529 62.55 15.2501H63.41V9.80007H62.9C61.9476 9.83926 61.017 10.0979 60.181 10.5558C59.3449 11.0138 58.6259 11.6586 58.08 12.4401ZM78.23 11.5801L77.97 11.6701C77.333 11.0424 76.5738 10.5525 75.7394 10.2308C74.9051 9.90914 74.0134 9.76251 73.12 9.80007C67.88 9.80007 64.68 14.6901 64.68 20.8701C64.68 27.0501 67.75 31.9401 72.68 31.9401C73.7033 31.9809 74.7214 31.7741 75.6476 31.3371C76.5739 30.9001 77.3809 30.2459 78 29.4301L78.26 29.5101V31.5101H84.18V10.2201H78.23V11.5801ZM78.23 24.1901C77.9017 25.0804 77.3003 25.8441 76.5119 26.3722C75.7235 26.9002 74.7883 27.1655 73.84 27.1301C71.58 27.1301 70.6 24.4901 70.6 20.8701C70.6 17.2501 71.6 14.6501 73.84 14.6501C75.4336 14.6111 76.9893 15.1392 78.23 16.1401V24.1901ZM99.14 4.86006C100.122 4.85771 101.098 5.01302 102.03 5.32006L102.76 0.890064C101.38 0.274005 99.881 -0.0298894 98.37 6.45106e-05C93.64 6.45106e-05 90.62 3.28007 90.62 8.30007V10.2201H87.68V14.7401H90.62V31.5201H96.54V14.7401H100.54V10.2201H96.54V8.30007C96.54 5.92006 97.43 4.86006 99.14 4.86006ZM115.19 26.1901C114.504 26.4825 113.765 26.6289 113.02 26.6201C111.74 26.6201 110.85 25.7201 110.85 23.6201V14.7401H115.15V10.2201H110.85V3.41006H105V10.2201H102.36V14.7401H105V23.8901C105 28.8901 107.94 31.7301 111.94 31.7301C113.327 31.7655 114.702 31.4562 115.94 30.8301L115.19 26.1901ZM0 31.6801H16.83V36.3701H0V31.6801Z" fill="currentColor"/>
    </g>
    <defs>
      <clipPath id="clip0_2599_1170">
        <rect width="115.92" height="36.37" fill="white"/>
      </clipPath>
    </defs>
  </svg>
</div>

  <!-- <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/wraft/wraft/main/priv/static/images/WidthFull.svg" />
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/wraft/wraft/main/priv/static/images/WidthFull.svg" />
    <img src=https://raw.githubusercontent.com/wraft/wraft/main/priv/static/images/WidthFull.svg" alt="Wraft" style="width: 180px;" />
  </picture> -->
</div>
</br>

<p align="center">
  The open-source Document Lifecycle Management platform.
</p>

<p align="center">
    <a href="https://wraft.app/"><b>Website</b></a> •
    <a href="https://github.com/wraft/wraft/releases"><b>Releases</b></a> •
    <a href="https://x.com/getwraft"><b>Twitter</b></a> •
    <a href="https://docs.wraft.app/developers"><b>Documentation</b></a>
</p>

<div align="center">
  <img src="priv/static/images/screenshot01.png" alt="Wraft Cover" style="width: 70%;" />
</div>

# Wraft - Document Lifecycle Management

Wraft is an open-source content authoring platform that's helps businesses produce their most important set of documents.
Wraft helps author structured business content. From official letters to contracts, and beyond.

Our goal is to give people complete control over their most important documents, from drafting to collaborating and distributing.

Wraft is built on top of open formats, using markdown and JSON. This means your content is always accessible and future-proof.

## Table of contents

- [Wraft](#wraft-docs)
- [Table of contents](#table-of-contents)
  - [Development](#development)
    - [Pre-requisite](#pre-requisite)
    - [Initial setup](#initial-setup)
  - [Running Wraft](#running-wraft-docs)
  - [Testing Wraft](#testing-wraft-docs)
  - [Others](#others)
    - [Few additional `mix tasks`](#few-additional-mix-tasks)

## Development

#### Pre-requisite

- Elixir 1.18.4
- Erlang/OTP 27.0.1
- Postgres
- Minio - S3 compatible object storage
- Pandoc 3.6.3
- ImageMagick
- Latex
- Typst 0.13.0
- Java 17 (for PDF signing)
- Rust toolchain (for native dependencies)

`.tool-versions` will have the exact versions defined in it.

#### Initial setup

### 1 - **Clone the repository**

```shell
$ git clone https://github.com/wraft/wraft.git
$ cd wraft
```

### 2 - **Elixir & Erlang**

As these 2 are defined in the `.tool_versions`, `asdf` will install the right versions with the following set of commands:

Please refer the given link for the installation of [asdf-version-manager](https://asdf-vm.com/#/core-manage-asdf-vm?id=install).

Add the following plugins to your asdf for elixir and erlang:

```shell
$ asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git

$ asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
```

```shell
$ asdf install
```

⚠️ For Ubuntu users, you also need to install the inotify-tools package.

**inotify-tools**

- command-line utilities to monitor file system activity

In macOS:

```shell
$ brew install inotify-tools
```

In Linux:

```shell
$ sudo apt install inotify-tools
```

### 3 - **Postgres**

Select your OS from the options [here](https://www.postgresql.org/download/) and follow the instruction to
install the latest version of postgres.
Check your installation using:

```shell
$  postgres -V
```

Test your connectivity:

```shell
$ psql -h 127.0.0.1 -p 5432 -U postgres postgres
```

### 4 - **Minio**

Download the latest version of minio from [here](https://min.io/docs/minio/linux/index.html) and follow the instructions to install based on your OS.

Run the following command from the system terminal or shell to start a local MinIO instance using the ~/minio folder. You can replace this path with another folder path on the local machine:

```shell
$ minio server ~/minio
$ minio server ~/minio --console-address :9001
```

Open http://127.0.0.1:9000 in a web browser to access the MinIO Console.

### 5 - **Pandoc**

##### **macOS**

The easiest way to install it on OSX is via brew:

```shell
$ brew install pandoc
```

##### **Linux**

For Linux machines, follow the instructions below.

- Download the pandoc package that suits your device [here](https://github.com/jgm/pandoc/releases/tag/2.9.2.1)
- To install the deb:

```shell
$ sudo dpkg -i $DEB
```

where `$DEB` is the path to the downloaded deb.

These instructions are taken from [Official Pandoc Documentations](https://pandoc.org/installing.html).
You may refer if the official documentation if you have any doubts.

### 6 - **ImageMagick**

To use ImageMagick, install the ImageMagick distribution from [here](https://imagemagick.org/script/download.php) appropriate to your OS.

For linux:
```sh
sudo apt update
sudo apt install imagemagick
```

### 7 - **Latex**

To use Latex in OSX, install the MacTex Distribution. You can download MacTex [here](https://www.tug.org/mactex/).
Choose the correct version that supports your device, download and install. Latex editor comes with the distribution.

In Linux machines, we suggest to use Tex Live LaTeX distribution. Easiest way to install Tex Live distribution in
Linux/Ubuntu is to use `apt-get`.

```shell
$ sudo apt-get install texlive-full
```

In case you need latex editor, type in:

```shell
$ sudo apt-get install texmaker
```

### 8 - **Typesense**

Typesense is a fast, typo-tolerant search engine used by Wraft for search functionality.

For detailed installation instructions, refer to the [official Typesense documentation](https://typesense.org/docs/guide/install-typesense.html#option-2-local-machine-self-hosting).

Download from [Typesense releases](https://github.com/typesense/typesense/releases) or run manually:

```shell
$ mkdir -p ~/typesense-data
$ typesense-server --data-dir ~/typesense-data --api-key=your-api-key-here
```

**Note:** Replace `your-api-key-here` with a secure API key. Default port is 8108.

### 9 - Running Wraft

To start your Wraft app:

**Load env variables**

Make a .env.dev file in the root directory and add the environment variables.
Refer `.env.example` for the list of variables.

Source the environment variables from the file and start the server.

```shell
$ mv .env.example .env.dev
$ source .env.dev
```

Setup the project

```shell
$ mix setup
```

**Start Phoenix endpoint**

- With interactive shell

```shell
$ iex -S mix phx.server
```

- Without interactive shell

```shell
$ source .env.dev && mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To get the API documentation, go [here](http://localhost:4000/api/swagger/index.html#/).

### 10 - Frontend

Clone the frontend repository separately.

```shell
$ cd ..
$ git clone https://github.com/wraft/wraft-frontend.git
$ cd wraft-frontend
```

Refer the README.md in the frontend repository for the setup.

### 11 - Default User

The default username and password

```bash
username: wraftuser@gmail.com
password: demo@1234
```

---

## Setup using Docker Compose

The easiest way to get started with Wraft is using Docker. The Docker setup includes all required dependencies and services.

### Prerequisites

- Docker and Docker Compose installed on your system
- Git

### Quick Start

1. **Clone the repository and navigate into it**  

```shell
git clone https://github.com/wraft/wraft.git
cd wraft
```
2. **Copy the example environment file and update it**

```shell
cp .env.example .env.dev
```

3. **Load environment variables**

```shell
source .env.dev
```

4. **Add MinIO host entry**

```shell
# macOS / Linux
echo "127.0.0.1 minio" | sudo tee -a /etc/hosts

# Windows
echo 127.0.0.1 minio >> C:\Windows\System32\drivers\etc\hosts
```

5. **Start all Docker containers**

```shell
docker-compose up -d
```

6. **Visit the application**

```shell
# Frontend
open http://localhost:3200
```

##### Default Credentials

```bash
username: wraftuser@gmail.com
password: demo@1234
```

### What's Included

The Docker setup includes:

- **Backend**: Elixir 1.18.4 with Erlang 27.0.1
- **Frontend**: React application
- **Database**: PostgreSQL 14
- **Object Storage**: MinIO (S3-compatible)
- **Search Engine**: Typesense
- **Dependencies**: Pandoc 3.6.3, Typst 0.13.0, LaTeX, ImageMagick, Java 17, Rust toolchain

#### Services and Ports

- **Frontend**: http://localhost:3200
- **Backend API**: http://localhost:4000
- **MinIO Console**: http://localhost:9001
- **PostgreSQL**: localhost:5433
- **Typesense**: localhost:8108



##### Environment Variables

Make sure to configure the following environment variables in your `.env.dev` file:

- `SECRET_KEY_BASE`
- `DEV_DB_USERNAME`, `DEV_DB_PASSWORD`, `DEV_DB_NAME` 
- `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`
- `TYPESENSE_API_KEY`
- `CLOAK_KEY`
- `GUARDIAN_KEY`
- And other required variables (see `.env.example`)

#### Stopping the Services

```shell
$ docker-compose down
```

To remove all data volumes as well:

```shell
$ docker-compose down -v
```
## Contributors
<a href="https://github.com/wraft/wraft/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=wraft/wraft" />
</a>


## License

Wraft is open-source software licensed under the [AGPLv3](LICENSE.md).
