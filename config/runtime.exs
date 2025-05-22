import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Start the phoenix server if environment is set and running in a  release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :wraft_doc, WraftDocWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :wraft_doc, WraftDoc.Repo,
    ssl: true,
    ssl_opts: [verify: :verify_none],
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    Map.fetch!(System.get_env(), "SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :wraft_doc, WraftDocWeb.Endpoint,
    url: [host: host, port: port],
    server: true,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :wraft_doc, WraftDocWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :wraft_doc, WraftDoc.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

config :wraft_doc, WraftDoc.Client.Razorpay,
  api_key: System.get_env("RAZORPAY_KEY_ID"),
  secret_key: System.get_env("RAZORPAY_KEY_SECRET")

config :wraft_doc, WraftDocWeb.Guardian, secret_key: System.get_env("GUARDIAN_KEY")

config :waffle,
  # "wraft"
  bucket: System.get_env("MINIO_BUCKET"),
  # "http://127.0.0.1:9000"
  asset_host: System.get_env("MINIO_URL")

minio_schema =
  if schema = System.get_env("MINIO_SCHEMA") do
    schema <> "://"
  else
    "http://"
  end

config :ex_aws,
  access_key_id: System.get_env("MINIO_ROOT_USER"),
  secret_access_key: System.get_env("MINIO_ROOT_PASSWORD"),
  s3: [
    scheme: minio_schema,
    host: System.get_env("MINIO_HOST"),
    port: System.get_env("MINIO_PORT")
  ]

config :ex_typesense,
  api_key: System.get_env("TYPESENSE_API_KEY"),
  host: System.get_env("TYPESENSE_HOST") || "localhost",
  port: String.to_integer(System.get_env("TYPESENSE_PORT") || "8108"),
  scheme: System.get_env("TYPESENSE_SCHEME") || "http",
  options: %{}

config :wraft_doc, WraftDocWeb.Mailer, api_key: System.get_env("SENDGRID_API_KEY")

config :wraft_doc, sender_email: "no-reply@#{System.get_env("WRAFT_HOSTNAME")}"

config :pdf_generator,
  wkhtml_path: System.get_env("WKHTMLTOPDF_PATH"),
  pdftk_path: System.get_env("PDFTK_PATH")

config :wraft_doc, :paddle,
  api_key: System.get_env("PADDLE_API_KEY"),
  webhook_secret_key: System.get_env("PADDLE_WEBHOOK_SECRET_KEY"),
  base_url: System.get_env("PADDLE_BASE_URL")

# Configure Sentry
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: "production"
  },
  included_environments: [:prod]

# Do not print debug messages in production
config :logger,
  level: :info,
  backends: [:console, Sentry.LoggerBackend]
