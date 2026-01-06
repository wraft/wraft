# test/test_helper.exs
ExUnit.start(formatters: [ExUnit.CLIFormatter, Bureaucrat.Formatter])

# Configure Ecto sandbox
Ecto.Adapters.SQL.Sandbox.mode(WraftDoc.Repo, :manual)

# Bureaucrat setup
Bureaucrat.start(
  env_var: "DOC",
  writer: Bureaucrat.SwaggerSlateMarkdownWriter,
  default_path: "doc/source/index.html.md",
  swagger: OpenApiSpex.OpenApi.to_map(WraftDocWeb.ApiSpec.spec())
)
