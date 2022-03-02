defmodule WraftDoc.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :wraft_doc,
      version: "0.0.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Coveralls
      app: :excoveralls,
      version: "1.0.0",
      elixir: "~> 1.0.0",
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {WraftDoc.Application, []},
      extra_applications: [:logger, :runtime_tools, :waffle_ecto]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.6"},
      {:phoenix_pubsub, "~> 2.0.0"},
      {:phoenix_ecto, "~> 4.4.0"},
      {:phoenix_view, "~> 1.1.0"},
      {:ecto_sql, "~> 3.7.1"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.2.0", override: true},
      {:phoenix_live_reload, "~> 1.3.3", only: :dev},
      {:esbuild, "~> 0.3", runtime: Mix.env() == :dev},
      {:gettext, "~> 0.18.2"},
      {:plug_cowboy, "~> 2.5.2"},
      {:distillery, "~> 2.1.1"},
      # Password encryption
      {:comeonin, "~> 5.3.2"},
      {:bcrypt_elixir, "~> 2.3.0"},
      # User authentication
      {:guardian, "~> 2.2.1"},
      {:guardian_phoenix, "~> 2.0"},
      # CORS
      {:cors_plug, "~> 2.0.2"},
      # File upload to AWS
      {:waffle, "~> 1.1.5"},
      {:waffle_ecto, "~> 0.0.11"},
      # Waffle support for AWS S3
      {:ex_aws, "~> 2.2.9"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.18.0"},
      {:sweet_xml, "~> 0.7.2"},
      # Time and date formating
      {:timex, "~>  3.7.6"},
      # JSON parser
      {:jason, "~> 1.3.0"},
      # API documentation
      {:phoenix_swagger, "~> 0.8.2"},

      # For Writing Api documentation by slate
      {:bureaucrat, "~> 0.2.5"},
      {:ex_json_schema, "~> 0.7.1"},
      # For testing
      {:ex_machina, "~> 2.7", only: :test},
      {:bypass, "~> 2.1.0", only: :test},
      {:excoveralls, "~> 0.14.4", only: :test},
      {:faker, "~> 0.17", only: :test},
      # Pagination
      {:scrivener_ecto, "~> 2.7.0"},
      {:scrivener_list, "~> 2.0.1"},
      # QR code generation
      {:eqrcode, "~> 0.1.10"},
      # Background jobs
      {:oban, "~> 2.10.1"},
      # Email client
      {:bamboo, "~> 2.2.0"},
      {:httpoison, "~> 1.8.0"},

      # Activity stream
      {:spur, git: "https://github.com/shijithkjayan/spur.git", branch: :master},
      {:ex_audit, "~> 0.9.0"},

      # CSV parser
      {:csv, "~> 2.4.1"},
      # Live dashboard
      {:phoenix_live_dashboard, "~> 0.6.2"},
      # Business logic flow
      {:opus, "~> 0.8.3"},
      # Razorpay
      {:razorpay, "~> 0.5.0"},
      # PDF generation using wkhtmltopdf
      {:pdf_generator, "~> 0.6.2"},

      # For admin pannel
      {:kaffy, "~> 0.9.0"},
      {:ecto_enum, "~> 1.4"},

      # Code analysis tool
      {:credo, "~> 1.6.1", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      swagger: ["phx.swagger.generate priv/static/swagger.json"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
