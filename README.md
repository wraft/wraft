# Wraft Docs

Wraft Docs is a simple, yet powerful document generation app. Using Wraft Doc it is very easy to generate and manage documents.

The aim of Wraft Docs is to maintain a single source of truth for document generation.

To start your Wraft docs app:

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.create && mix ecto.migrate`
- Source the .env file with `source .env`
- Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Get the API documentation

- After starting the Pheonix server, go to `http://localhost:4000/api/swagger/index.html#/`

Test the app

- Source the .env file with `source .env`
- Start testing with `mix test`

## Pre-requisite

### Pandoc

This assumes you have `pandoc` installed in your device. The easiest way to install it on OSX is via brew:

```
$ brew install pandoc
```

For Linux machines, follow the instructions below.

- Download the pandoc package that suits your device [here](https://github.com/jgm/pandoc/releases/tag/2.9.2.1)
- To install the deb:

```
sudo dpkg -i $DEB
```

where \$DEB is the path to the downloaded deb.

These instructions are taken from [Official Pandoc Documentations](https://pandoc.org/installing.html). You may refer if the official documentation if you have any doubts.

### Latex

To use Latex in macOS, its better to install the MacTex Distribution. You can download MacTex [here](https://www.tug.org/mactex/). Choose the correct version that supports your device, download and install. Latex editor comes with the distribution.

In Linux machines, we suggest to use Tex Live LaTeX distribution. Easiest way to install Tex Live distribution in Linux/Ubuntu is to use `apt-get`.

```
sudo apt-get install texlive-full
```

In case you need latex editor, type in:

```
sudo apt-get install texmaker
```

### Gnuplot

In macOS:

```
brew install gnuplot
```

In Linux:

```
sudo apt-get install gnuplot
```

##### Extra Dependencies used

The dependencies used, other than the default ones, are listed below

- Comeonin v5.1.3 and bcrypt_elixir v2.0.3
  - Used for password encryption and verification.
- Guardian v2.0.0
  - Used for user authentication.
- cors_plug v2.0.2
  - CORS validation
- waffle v0.11.0 and waffle_ecto v0.11.3
  - File upload
- Timex v3.6.1
  - Date/Time library
- Jason v1.1 and Poison v3.0
  - JSON parser
- phoenix_swagger v0.8.2
  - Swagger API documentation
- Bureaucrat v0.2.5 and ex_json_schema v0.5
  - SLATE API documentation
- ex_machina v2.3
  - Build datas for tests
- scrivener_ecto v2.3
  - Pagination
- Eqrcode v0.1.7
  - Generate QR code in SVG/PNG formats
- Oban v1.2
  - Job processing library
- Bamboo v1.4
  - Email client
- HTTPoision v1.6
  - HTTP client for elixir
- Spur
  - Activity stream
- CSV
  - CSV parser
- Phoenix Live Dashboard v0.1.0
  - Dashboard
