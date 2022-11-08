defmodule WraftDoc.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :wraft_doc,
      version: "0.0.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers() ++ [:phoenix_swagger],
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
  defp elixirc_paths(:dev), do: ["lib", "priv/repo"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.15"},
      {:phoenix_pubsub, "~> 2.1.1"},
      {:phoenix_ecto, "~> 4.4.0"},
      {:phoenix_view, "~> 2.0.1"},
      {:ecto_sql, "~> 3.9.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.2.0", override: true},
      {:phoenix_live_reload, "~> 1.4.0", only: :dev},
      # Live dashboard
      {:phoenix_live_dashboard, "~> 0.7.2", override: true},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:gettext, "~> 0.20.0"},
      {:plug_cowboy, "~> 2.6.0"},
      {:distillery, "~> 2.1.1"},
      # Password encryption
      {:comeonin, "~> 5.3.2"},
      {:bcrypt_elixir, "~> 3.0.1"},
      # User authentication
      {:guardian, "~> 2.3.0"},
      {:guardian_phoenix, "~> 2.0"},
      # CORS
      {:cors_plug, "~> 3.0.1"},
      # File upload to AWS
      {:waffle, "~> 1.1.5"},
      {:waffle_ecto, "~> 0.0.11"},
      # Waffle support for AWS S3
      {:ex_aws, "~> 2.4.0"},
      {:ex_aws_s3, "~> 2.3.3"},
      {:hackney, "~> 1.18.0"},
      {:sweet_xml, "~> 0.7.3"},
      # Time and date formating
      {:timex, "~>  3.7.9"},
      # JSON parser
      {:jason, "~> 1.4.0"},
      # API documentation
      {:phoenix_swagger, "~> 0.8.3"},

      # For Writing Api documentation by slate
      {:bureaucrat, "~> 0.2.9"},
      {:ex_json_schema, "~> 0.9.2", override: true},
      # For testing
      {:ex_machina, "~> 2.7", only: :test},
      {:bypass, "~> 2.1.0", only: :test},
      {:excoveralls, "~> 0.15.0", only: :test},
      {:faker, "~> 0.17", only: [:test, :dev]},
      # Pagination
      {:scrivener_ecto, "~> 2.7.0"},
      {:scrivener_list, "~> 2.0.1"},
      # QR code generation
      {:eqrcode, "~> 0.1.10"},
      # Background jobs
      {:oban, "~> 2.13.4"},
      # Email client
      {:bamboo, "~> 2.2.0"},
      {:httpoison, "~> 1.8.2"},
      {:poison, "~> 5.0.0", override: true},

      # Activity stream
      {:ex_audit, git: "https://github.com/Kry10-NZ/ex_audit", branch: "fix-ecto-3.8"},

      # CSV parser
      {:csv, "~> 3.0.3"},
      # Business logic flow
      {:opus, "~> 0.8.3"},
      # Razorpay
      {:razorpay, "~> 0.5.0"},
      # PDF generation using wkhtmltopdf
      {:pdf_generator, "~> 0.6.2"},

      # For admin pannel
      {:kaffy, "~> 0.9.4"},
      {:ecto_enum, "~> 1.4"},

      # Code analysis tool
      {:credo, "~> 1.6.7", only: [:dev, :test], runtime: false}
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
