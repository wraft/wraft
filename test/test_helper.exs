ExUnit.start(formatters: [ExUnit.CLIFormatter, Bureaucrat.Formatter])

# Start only your main application
{:ok, _} = Application.ensure_all_started(:wraft_doc)

# Set SQL sandbox mode after starting the application
case Ecto.Adapters.SQL.Sandbox.mode(WraftDoc.Repo, :manual) do
  :ok ->
    :ok

  {:error, reason} ->
    IO.warn("SQL Sandbox not available: #{inspect(reason)}")
end

# Mock definitions are in test/support/mocks.ex

# Bureaucrat setup
Bureaucrat.start(
  env_var: "DOC",
  writer: Bureaucrat.SwaggerSlateMarkdownWriter,
  default_path: "doc/source/index.html.md",
  swagger: "priv/static/swagger.json" |> File.read!() |> Jason.decode!()
)
