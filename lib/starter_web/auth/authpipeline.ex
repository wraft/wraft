defmodule StarterWeb.Guardian.AuthPipeline do
  @moduledoc """
  The pipeline that guradian follows to check and verify the users JWT token.
  """
  use Guardian.Plug.Pipeline,
    otp_app: :starter,
    module: StarterWeb.Guardian,
    error_handler: StarterWeb.Guardian.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader)
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
  plug StarterWeb.CurrentUser
end
