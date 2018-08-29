defmodule StarterWeb.Guardian.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :starter,
    module: StarterWeb.Guardian,
    error_handler: StarterWeb.Guardian.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader)
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
end
