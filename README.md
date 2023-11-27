# Wraft Docs

Wraft Docs is a simple, yet powerful document generation app. Using Wraft Doc it is very easy to generate and manage
documents.

The aim of Wraft Docs is to maintain a single source of truth for document generation.

# Table of contents
- [Wraft Docs](#wraft-docs)
- [Table of contents](#table-of-contents)
  - [Development](#development)
      - [Pre-requisite](#pre-requisite)
      - [Initial setup](#initial-setup)
  - [Running Wraft Docs](#running-wraft-docs)
  - [Testing Wraft Docs](#testing-wraft-docs)
  - [Others](#others)
      - [Few additional `mix tasks`](#few-additional-mix-tasks)

## Development
#### Pre-requisite
* Elixir 1.13
* Erlang/OTP 24.0
* Postgres
* Pandoc
* Latex
* Gnuplot
* wkhtmltopdf

`.tools_version` will have the exact versions defined in it.



#### Initial setup

**Elixir & Erlang**

As these 2 are defined in the `.tools_version`, `asdf` will install the right versions with the following command:
```shell
$ asdf install
```

**Postgres**

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

**Pandoc**

The easiest way to install it on OSX is via brew:

```shell
$ brew install pandoc
```

For Linux machines, follow the instructions below.

- Download the pandoc package that suits your device [here](https://github.com/jgm/pandoc/releases/tag/2.9.2.1)
- To install the deb:

```shell
$ sudo dpkg -i $DEB
```

where `$DEB` is the path to the downloaded deb.

These instructions are taken from [Official Pandoc Documentations](https://pandoc.org/installing.html).
You may refer if the official documentation if you have any doubts.

**Latex**

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

**Gnuplot**

In macOS:

```shell
$ brew install gnuplot
```

In Linux:

```shell
$ sudo apt-get install gnuplot
```

**wkhtmltopdf**

Download the latest package installer that matches your OS [here](https://wkhtmltopdf.org/downloads.html).
Open it and follow the instructions to install `wkhtmltopdf`.

To check your installation:

```shell
$ wkhtmltopdf -V
```

**Commit Hooks**
Wraft Docs uses `pre-commit` to standardise the code quality and style.

To install pre-commit:
Using pip:
```shell
$ pip install pre-commit
```
Using homebrew:
```shell
$ brew install pre-commit
```

To verify installation:

```shell
$ pre-commit --version
```

Now to setup pre commit for Wraft Docs:

```shell
$ pre-commit install
```

**direnv**

`direnv` is an environment switcher for the shell. It knows how to hook into bash, zsh, tcsh, fish shell and elvish to load or unload environment variables depending on the current directory. This allows project-specific environment variables without cluttering the "~/.profile" file.

Before using it, you need to install it. Here is how you can do it:

In macOS:

```shell
$ brew install direnv
```

In Linux:

```shell
$ sudo apt-get install direnv
```

Once installed, you need to hook direnv into your shell.

```shell
$ echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
```

Finally, you can use it in your project:

```shell
$ direnv allow
```

Now, whenever you enter the directory, the environment variables from `.envrc` will be loaded automatically. When you leave the directory, those variables get unloaded.


## Running Wraft Docs
To start your Wraft docs app:

**Install dependencies with**
```shell
$ mix deps.get
```

**Setup Database**
- With seed data

```shell
$ ecto.setup
```

- Without seed data
```shell
$ mix ecto.create && mix ecto.migrate
```

**Start Phoenix endpoint**
- With interactive shell
```shell
$ ies -S mix phoenix.server
```

- Without interactive shell
```shell
$ mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To get the API documentation, go [here](http://localhost:4000/api/swagger/index.html#/).

## Testing Wraft Docs
```shell
$ source .env && mix test
```

## Others
#### Few additional `mix tasks`
- Set up the project in one go
```shell
$ mix setup
```
- Generate API documentation
```shell
$ mix swagger
```
