import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wraft_doc, WraftDocWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],
  server: false,
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE")

# Print only warnings and errors during test
config :logger, level: :warning

config :wraft_doc, Oban,
  queues: false,
  plugins: false,
  testing: :disabled

config :wraft_doc, WraftDocWeb.Mailer, adapter: Swoosh.Adapters.Test

config :wraft_doc, WraftDoc.TypesenseServer, start: false

config :wraft_doc, permissions_file: "test/mix/tasks/csv/test_permissions.csv"

config :wraft_doc, :test_module, minio: ExAwsMock, razorpay: WraftDoc.Client.RazorpayMock

config :tesla, adapter: Tesla.Mock

config :waffle, storage: Waffle.Storage.Local

# Set is_self_hosted to false in test environment to enable payment routes
config :wraft_doc, :deployment, is_self_hosted: false

# Initialize plugs at runtime for faster test compilation
