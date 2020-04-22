Ecto.Adapters.SQL.Sandbox.mode(WraftDoc.Repo, :manual)

Bureaucrat.start(
  env_var: "DOC",
  writer: Bureaucrat.SwaggerSlateMarkdownWriter,
  default_path: "doc/source/index.html.md",
  swagger: "priv/static/swagger.json" |> File.read!() |> Poison.decode!()
)

{:ok, _} = Application.ensure_all_started(:ex_machina)
Application.ensure_all_started(:bypass)

ExUnit.start(formatters: [ExUnit.CLIFormatter, Bureaucrat.Formatter])
