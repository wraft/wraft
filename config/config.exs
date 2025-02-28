# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
# General application configuration
import Config

config :wraft_doc,
  ecto_repos: [WraftDoc.Repo]

# Configures the endpoint
config :wraft_doc, WraftDocWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: WraftDocWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: WraftDoc.PubSub,
  live_view: [signing_salt: "2B8BVDxqHCMKIa5cHoQ2lM0Ne7gUxvkb"]

config :wraft_doc, :deployement, is_self_hosted: System.get_env("SELF_HOSTED", "true") == "true"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.15.3",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id, :error, :status, :changeset, :path]

# Configures Guardian
config :wraft_doc, WraftDocWeb.Guardian,
  issuer: "wraft_doc",
  ttl: {2, :hours}

config :guardian, Guardian.DB,
  repo: WraftDoc.Repo,
  schema_name: "guardian_tokens",
  token_types: ["refresh"],
  sweep_interval: 60

config :wraft_doc, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      # phoenix routes will be converted to swagger paths
      router: WraftDocWeb.Router,
      # (optional) endpoint config used to set host, port and https schemes.
      endpoint: WraftDocWeb.Endpoint
    ]
  }

# By default, the Pruner plugin retains jobs for 60 seconds.
# You can configure a longer retention period by providing a `max_age: 60`
# in seconds to the Pruner plugin.
# Cron jobs Overview https://github.com/sorentwo/oban#periodic-jobs
config :wraft_doc, Oban,
  repo: WraftDoc.Repo,
  queues: [default: 10, events: 50, media: 20, mailer: 20],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 0 * * MON", WraftDoc.Workers.ScheduledWorker,
        queue: :scheduled, tags: ["unused_assets"]}
     ]}
  ]

# File Upload config
config :waffle,
  storage: Waffle.Storage.S3

config :ex_aws,
  json_codec: Jason,
  region: "local"

config :tesla, adapter: Tesla.Adapter.Hackney

config :tesla, Tesla.Middleware.Logger, filter_headers: ["authorization"], debug: false

config :wraft_doc, WraftDocWeb.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  sender_email: "no-reply@#{System.get_env("WRAFT_HOSTNAME")}"

config :ex_audit,
  ecto_repos: [WraftDoc.Repo],
  version_schema: WraftDoc.ExAudit.Version,
  tracked_schemas: [
    WraftDoc.Assets.Asset,
    WraftDoc.BlockTemplates.BlockTemplate,
    WraftDoc.Document.Block,
    WraftDoc.ContentTypes.ContentType,
    WraftDoc.DataTemplates.DataTemplate,
    WraftDoc.Document.Field,
    WraftDoc.Document.Instance,
    WraftDoc.Document.Instance.Version,
    WraftDoc.Document.OrganisationField,
    WraftDoc.Document.Pipeline,
    WraftDoc.Document.Pipeline.Stage,
    WraftDoc.Document.Theme,
    WraftDoc.Enterprise.ApprovalSystem,
    WraftDoc.Enterprise.ApprovalSystem,
    WraftDoc.Enterprise.Flow,
    WraftDoc.Enterprise.Flow,
    WraftDoc.Enterprise.Flow.State,
    WraftDoc.Enterprise.Flow.State,
    WraftDoc.Enterprise.Vendor,
    WraftDoc.Enterprise.Vendor,
    WraftDoc.Forms.Form,
    WraftDoc.Layouts.Layout,
    WraftDoc.Layouts.LayoutAsset,
    WraftDoc.Themes.Theme
  ],
  primitive_structs: [
    Date
  ]

config :wraft_doc, WraftDoc.Client.Razorpay, base_url: "https://api.razorpay.com/v1/payments"

config :pdf_generator,
  raise_on_missing_wkhtmltopdf_binary: false

config :kaffy,
  otp_app: :wraft_doc,
  admin_title: "Wraft Backoffice",
  admin_logo: "/images/WidthFull.svg",
  admin_logo_mini: "/images/WidthShort.svg",
  ecto_repo: WraftDoc.Repo,
  router: WraftDocWeb.Router,
  hide_dashboard: false,
  home_page: [kaffy: :dashboard],
  resources: &WraftDoc.Kaffy.Config.create_resources/1,
  extensions: [
    WraftDoc.Kaffy.Extension
  ]

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: WraftDoc.Repo

config :fun_with_flags, :cache,
  enabled: false,
  ttl: 900

config :wraft_doc,
  permissions_file: "priv/repo/data/rbac/permissions.csv",
  theme_folder: "priv/wraft_files/Roboto",
  layout_file: "priv/wraft_files/letterhead.pdf",
  default_template_files: "priv/wraft_files/templates",
  sender_email: "no-reply@#{System.get_env("WRAFT_HOSTNAME")}",
  frontend_url: "#{System.get_env("WRAFT_URL")}"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason
# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
