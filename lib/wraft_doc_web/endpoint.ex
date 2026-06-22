defmodule WraftDocWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :wraft_doc

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  socket("/socket", WraftDocWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  # `max_age` must stay in sync with `WraftDoc.InternalUsers.admin_session_max_age/0`
  # (the gates also enforce expiry via an issued-at value inside the session, so
  # old cookies die even if the cookie attribute is tampered with). `secure` and
  # the signing salt are compile-time config (`config/prod.exs`) — a release does
  # not re-read them from the environment at boot, so they live in config, not a
  # runtime `System.get_env`. The salt is a namespace, not the secret: cookie
  # integrity rests on `secret_key_base`.
  @session_options [
    store: :cookie,
    key: "_wraftdoc_key",
    signing_salt: Application.compile_env(:wraft_doc, :session_signing_salt, "hUnYtn2s"),
    max_age: WraftDoc.InternalUsers.admin_session_max_age(),
    same_site: "Lax",
    secure: Application.compile_env(:wraft_doc, :session_cookie_secure, false)
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(
    Plug.Static,
    at: "/",
    from: :wraft_doc,
    gzip: false,
    only: ~w(assets fonts images favicon.ico favicon.svg robots.txt)
  )

  plug(
    Plug.Static,
    at: "/uploads",
    from: "uploads"
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Logger)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    body_reader: {WraftDocWeb.RawBodyReader, :read_body, []}
  )

  plug Sentry.PlugContext

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug(Plug.Session, @session_options)
  plug(CORSPlug)
  plug(WraftDocWeb.Router)
end
