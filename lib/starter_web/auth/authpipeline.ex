defmodule ExStarterWeb.Guardian.AuthPipeline do
  @moduledoc """
  The pipeline that guradian follows to check and verify the users JWT token.
  """
  use Guardian.Plug.Pipeline,
    otp_app: :ex_starter,
    module: ExStarterWeb.Guardian,
    error_handler: ExStarterWeb.Guardian.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader)
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
  plug(ExStarterWeb.CurrentUser)
end
