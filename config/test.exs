import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :wraft_doc, WraftDocWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],
  server: false,
  secret_key_base: Map.fetch!(System.get_env(), "SECRET_KEY_BASE")

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :wraft_doc, WraftDoc.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  database: System.get_env("POSTGRES_DB") || "wraft_doc_test",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :wraft_doc, Oban, queues: false, plugins: false, testing: :inline

config :wraft_doc, WraftDocWeb.Mailer, adapter: Swoosh.Adapters.Test

config :wraft_doc, permissions_file: "test/mix/tasks/csv/test_permissions.csv"

config :wraft_doc, :test_module, minio: ExAwsMock, razorpay: WraftDoc.Client.RazorpayMock

config :tesla, adapter: Tesla.Mock

config :waffle, storage: Waffle.Storage.Local

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
