<div align="center">
  <img src="priv/static/images/wraft-logo.png" alt="Wraft" style="width: 100%;" />
</div>

<p align="center">
  The open-source Contract Lifecycle Management platform.
</p>

<div align="center">
  <img src="priv/static/images/screenshot01.png" alt="Wraft Cover" style="width: 70%;" />
</div>

# Wraft - Contract Lifecycle Management

Wraft is a simple, yet powerful document generation app. Using Wraft Doc it is very easy to generate and manage
documents.

The aim of Wraft is to maintain a single source of truth for document generation.

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

- Elixir 1.14
- Erlang/OTP 25.0
- Postgres
- Minio - S3 compatible object storage
- Pandoc
- Latex

`.tools_version` will have the exact versions defined in it.

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

### 6 - **Latex**

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

### 7 - Running Wraft

To start your Wraft app:

**Load env variables**

Make a .dev.env file in the root directory and add the environment variables.
Refer `.env.example` for the list of variables.

Source the environment variables from the file and start the server.

```shell
$ mv .env.example .dev.env
$ source .dev.env
```

**Install dependencies with**

```shell
$ mix deps.get
```

**Setup Database**

- With seed data

```shell
$ mix ecto.setup
```

- Without seed data

```shell
$ mix ecto.create && mix ecto.migrate
```

**Start Phoenix endpoint**

- With interactive shell

```shell
$ iex -S mix phx.server
```

- Without interactive shell

```shell
$ source .dev.env && mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To get the API documentation, go [here](http://localhost:4000/api/swagger/index.html#/).

### 8 - Frontend

Clone the frontend repository separately.

```shell
$ cd ..
$ git clone https://github.com/wraft/wraft-frontend.git
$ cd wraft-frontend
```

### 9 - Default User

The default username and password

```bash
username: wraftuser@gmail.com
password: password
```

Refer the README.md in the frontend repository for the setup.

---

## Setup using Docker

The easiest way to get started with wraft-backend is using Docker by running the following command.

```shell
$ git clone https://github.com/wraft/wraft.git
$ cd wraft

# Copy the example env to your own file and edit it
$ cp .env.example .dev.env

#Load the development environment variables
$ source .dev.env

# Start the Docker containers
$ docker-compose up -d

# Visit localhost:4000
$ http://localhost:4000
```

## License

Wraft is open-source software licensed under the [AGPLv3](LICENSE).
