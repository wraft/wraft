defmodule WraftDocWeb.Guardian.AuthPipeline do
  @moduledoc """
  The pipeline that guardian follows to check and verify the users JWT token.
  """
  use Guardian.Plug.Pipeline,
    otp_app: :wraft_doc,
    module: WraftDocWeb.Guardian,
    error_handler: WraftDocWeb.Guardian.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader)
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
  plug(WraftDocWeb.CurrentUser)
  plug(WraftDocWeb.CurrentOrganisation)
end
