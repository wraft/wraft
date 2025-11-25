ExUnit.start(formatters: [ExUnit.CLIFormatter, Bureaucrat.Formatter])

# Set SQL sandbox mode before starting the application
case Ecto.Adapters.SQL.Sandbox.mode(WraftDoc.Repo, :manual) do
  :ok ->
    :ok

  {:error, reason} ->
    IO.warn("SQL Sandbox not available: #{inspect(reason)}")
end

# Start only your main application
{:ok, _} = Application.ensure_all_started(:wraft_doc)

# Mock definitions
if Code.ensure_loaded?(Mox) do
  Mox.defmock(ExAwsMock, for: ExAws.Behaviour)
  Mox.defmock(WraftDoc.Client.RazorpayMock, for: WraftDoc.Client.Razorpay.Behaviour)
end

# Bureaucrat setup
Bureaucrat.start(
  env_var: "DOC",
  writer: Bureaucrat.SwaggerSlateMarkdownWriter,
  default_path: "doc/source/index.html.md",
  swagger: "priv/static/swagger.json" |> File.read!() |> Jason.decode!()
)
