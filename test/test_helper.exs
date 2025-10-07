Application.ensure_all_started(:wraft_doc)

# Set up Mox expectations for test environment
Mox.set_mox_global()
ExUnit.start()

# Set up global expectations for ExAwsMock
Mox.expect(ExAwsMock, :request, fn operation ->
  case operation do
    %ExAws.Operation.S3{http_method: :head, path: "/"} ->
      {:ok, %{status_code: 200}}

    _ ->
      {:ok, %{status_code: 200}}
  end
end)

Ecto.Adapters.SQL.Sandbox.mode(WraftDoc.Repo, :manual)

Bureaucrat.start(
  env_var: "DOC",
  writer: Bureaucrat.SwaggerSlateMarkdownWriter,
  default_path: "doc/source/index.html.md",
  swagger: "priv/static/swagger.json" |> File.read!() |> Jason.decode!()
)

Faker.start()
{:ok, _} = Application.ensure_all_started(:ex_machina)
Application.ensure_all_started(:bypass)

ExUnit.start(formatters: [ExUnit.CLIFormatter, Bureaucrat.Formatter])
