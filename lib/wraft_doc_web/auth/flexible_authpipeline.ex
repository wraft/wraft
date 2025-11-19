defmodule WraftDocWeb.Guardian.FlexibleAuthPipeline do
  @moduledoc """
  A flexible authentication pipeline that supports both API Key and JWT authentication.
  
  This pipeline:
  1. First attempts API Key authentication (X-API-Key header)
  2. If no API key, falls back to JWT authentication (Authorization: Bearer header)
  3. If either succeeds, sets current_user and current_organisation
  4. If both fail, returns 401 Unauthorized
  
  This allows the same endpoints to work with both authentication methods.
  """
  use Guardian.Plug.Pipeline,
    otp_app: :wraft_doc,
    module: WraftDocWeb.Guardian,
    error_handler: WraftDocWeb.Guardian.AuthErrorHandler

  # Try API key authentication first
  plug(WraftDocWeb.Plug.ApiKeyAuth)
  
  # Then try JWT authentication (only if API key didn't succeed)
  plug(Guardian.Plug.VerifyHeader, claims: %{})
  plug(Guardian.Plug.LoadResource, allow_blank: true)
  
  # Load user context (works for both auth methods)
  plug(WraftDocWeb.CurrentUser)
  plug(WraftDocWeb.CurrentOrganisation)
  
  # Finally, ensure we have authentication from either method
  plug(WraftDocWeb.Plug.EnsureAuthenticated)
end

