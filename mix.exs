defmodule WraftDoc.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :wraft_doc,
      version: "0.4.3",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Coveralls
      app: :excoveralls,
      version: "1.0.0",
      elixir: "~> 1.0.0",
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      releases: [
        wraft_doc: [
          include_executables_for: [:unix],
          applications: [wraft_doc: :permanent],
          steps: [:assemble, :tar]
        ]
      ],
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
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1.1"},
      {:phoenix_ecto, "~> 4.4.0"},
      {:phoenix_view, "~> 2.0.2"},
      {:ecto_sql, "~> 3.11.1"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3.1", override: true},
      {:phoenix_live_reload, "~> 1.4.0", only: :dev},
      # Live dashboard
      {:phoenix_live_dashboard, "~> 0.8.6", override: true},
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev},
      {:gettext, "~> 0.20.0"},
      {:plug_cowboy, "~> 2.7.0"},
      {:distillery, "~> 2.1.1"},
      # Password encryption
      {:comeonin, "~> 5.3.2"},
      {:bcrypt_elixir, "~> 3.0.1"},
      # User authentication
      {:guardian, "~> 2.3.2"},
      {:guardian_db, "~> 3.0.0"},
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
      {:timex, "~>  3.7.11"},
      # Phone number validation
      {:ex_phone_number, "~> 0.4.2"},
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
      {:faker, "~> 0.17"},
      {:mox, "~> 1.0"},
      {:floki, "~> 0.36.0"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      # Pagination
      {:scrivener_ecto, "~> 2.7.0"},
      {:scrivener_list, "~> 2.0.1"},
      # QR code generation
      {:eqrcode, "~> 0.1.10"},
      # Background jobs
      {:oban, "~> 2.19.2"},
      {:oban_web, "~> 2.11"},
      # Email client
      {:swoosh, "~> 1.8.3"},
      {:httpoison, "~> 1.8.2"},
      {:tesla, "~> 1.7.0"},
      {:poison, "~> 5.0.0", override: true},

      # Activity stream
      {:ex_audit, git: "https://github.com/Kry10-NZ/ex_audit", branch: "fix-ecto-3.8"},

      # CSV parser
      {:csv, "~> 3.0.3"},
      # Business logic flow
      {:opus, "~> 0.8.3"},
      # PDF generation using wkhtmltopdf
      {:pdf_generator, "~> 0.6.2"},
      # zip file
      {:unzip, "~> 0.11"},

      # Create and cleanup Tempfile
      {:briefly, "~> 0.5.0"},
      {:sizeable, "~> 1.0"},

      # For admin pannel
      {:kaffy, "~> 0.10.0"},
      {:ecto_enum, "~> 1.4"},

      # Code analysis tool
      {:credo, "~> 1.6.7", only: [:dev, :test], runtime: false},

      # Feature Flags
      {:fun_with_flags, "~> 1.10.1", runtime: false},
      {:fun_with_flags_ui, "~> 0.8.1"},

      # Sentry
      {:sentry, "~> 10.2.0"},

      # mjml
      {:mjml, "~> 3.0"},
      {:mjml_eex, "~> 0.10.0"},

      # search
      {:ex_typesense, "~> 0.6"},

      # live collaboration
      {:y_ex, "~> 0.6.5"},

      # markdown
      {:mdex, "~> 0.3.3"},
      {:file_type, "~> 0.1.0"},
      {:rustler, "~> 0.32.0", runtime: true}
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
      "ecto.start": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      swagger: ["phx.swagger.generate priv/static/swagger.json"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
