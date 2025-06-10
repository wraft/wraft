defmodule WraftDoc.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :wraft_doc,
      version: "0.4.3",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Coveralls
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
      {:bcrypt_elixir, "~> 3.2"},
      {:briefly, "~> 0.5"},
      {:bureaucrat, "~> 0.2"},
      {:bypass, "~> 2.1", only: :test},
      {:comeonin, "~> 5.3"},
      {:cors_plug, "~> 3.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:csv, "~> 3.2"},
      {:distillery, "~> 2.1.1"},
      {:ecto_enum, "~> 1.4"},
      {:ecto_sql, "~> 3.12"},
      {:eqrcode, "~> 0.2.1"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:ex_audit, git: "https://github.com/Kry10-NZ/ex_audit", branch: "fix-ecto-3.8"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_json_schema, "~> 0.9", override: true},
      {:ex_machina, "~> 2.8", only: :test},
      {:ex_phone_number, "~> 0.4"},
      {:ex_typesense, "~> 0.6"},
      {:excoveralls, "~> 0.18", only: :test},
      {:faker, "~> 0.18"},
      {:file_type, "~> 0.1"},
      {:floki, "~> 0.36"},
      {:fun_with_flags, "~> 1.11", runtime: false},
      {:fun_with_flags_ui, "~> 0.8"},
      {:gettext, "~> 0.26"},
      {:guardian, "~> 2.3"},
      {:guardian_db, "~> 3.0"},
      {:guardian_phoenix, "~> 2.0"},
      {:hackney, "~> 1.20"},
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:kaffy, "~> 0.10.3"},
      {:mdex, "~> 0.3"},
      {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
      {:mjml, "~> 4.0"},
      {:mjml_eex, "~> 0.12"},
      {:mox, "~> 1.1"},
      {:oban, "~> 2.19"},
      {:oban_web, "~> 2.11"},
      {:opus, "~> 0.8"},
      {:pdf_generator, "~> 0.6"},
      {:phoenix, "~> 1.7.17"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_html, "~> 4.1", override: true},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8.6", override: true},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_swagger, "~> 0.8"},
      {:phoenix_view, "~> 2.0"},
      {:plug_cowboy, "~> 2.7"},
      {:poison, "~> 6.0", override: true},
      {:postgrex, ">= 0.0.0"},
      {:rustler, "~> 0.34", runtime: true},
      {:oauth2, "~> 2.0"},
      {:scrivener_ecto, "~> 3.1"},
      {:scrivener_list, "~> 2.1"},
      {:sentry, "~> 10.8"},
      {:sizeable, "~> 1.0"},
      {:sweet_xml, "~> 0.7"},
      {:swoosh, "~> 1.16"},
      {:tesla, "~> 1.12"},
      {:timex, "~> 3.7.12"},
      {:unzip, "~> 0.12"},
      {:waffle, "~> 1.1"},
      {:waffle_ecto, "~> 0.0.12"},
      {:y_ex, "~> 0.6"},
      {:assent, "~> 0.3.0"},
      {:mint, "~> 1.0"},
      {:castore, "~> 1.0"},
      {:jido, "~> 1.1.0-rc.2"},
      {:jido_ai, github: "wraft/jido_ai", override: true},
      {:instructor, github: "thmsmlr/instructor_ex", override: true},
      {:cloak_ecto, "~> 1.3.0"}
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
      "assets.deploy": ["esbuild default --minify", "phx.digest"],
      quality: [
        "format",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --all"
      ]
    ]
  end
end
