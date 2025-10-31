# test/test_helper.exs
ExUnit.start(formatters: [ExUnit.CLIFormatter, Bureaucrat.Formatter])

# Start dependencies
{:ok, _} = Application.ensure_all_started(:wraft_doc)
{:ok, _} = Application.ensure_all_started(:ex_machina)
{:ok, _} = Application.ensure_all_started(:bypass)
Faker.start()

# Mock definitions
Code.ensure_loaded?(Mox)

Mox.defmock(ExAwsMock, for: ExAws.Behaviour)
Mox.defmock(WraftDoc.Client.RazorpayMock, for: WraftDoc.Client.Razorpay.Behaviour)

# Set SQL sandbox mode
Ecto.Adapters.SQL.Sandbox.mode(WraftDoc.Repo, :manual)

# Bureaucrat setup
Bureaucrat.start(
  env_var: "DOC",
  writer: Bureaucrat.SwaggerSlateMarkdownWriter,
  default_path: "doc/source/index.html.md",
  swagger: "priv/static/swagger.json" |> File.read!() |> Jason.decode!()
)

# No Mox.set_mox_global() here!
# We’ll use :set_mox_from_context in each test case instead
