defmodule WraftDocWeb.Api.V1.IntegrationAuthController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  alias WraftDoc.Integrations.DocuSign

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  def swagger_definitions do
    %{
      AuthUrlResponse:
        swagger_schema do
          title("Authorization URL Response")
          description("Response containing the DocuSign authorization URL")

          properties do
            status(:string, "Status of the request", required: true, example: "success")

            redirect_url(:string, "URL to redirect the user for DocuSign authorization",
              required: true
            )
          end

          example(%{
            status: "success",
            redirect_url:
              "https://account-d.docusign.com/oauth/auth?response_type=code&scope=signature&..."
          })
        end
    }
  end

  swagger_path :auth do
    get("/docusign/auth")
    summary("Get DocuSign authorization URL")
    description("Returns the authorization URL for initiating the DocuSign OAuth flow")
    tag("Integrations")

    response(200, "Success", Schema.ref(:AuthUrlResponse))
    response(403, "Unauthorized")
  end

  @doc """
  Returns the DocuSign authorization URL.

  This endpoint generates and returns a URL that redirects the user to the DocuSign
  authorization page where they can authorize the application to access their DocuSign account.
  The URL includes the necessary parameters for the OAuth flow including client ID,
  redirect URI, and PKCE challenge.

  The organization ID is obtained from the current user's session.
  """
  @spec auth(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def auth(conn, _params) do
    organisation_id = conn.assigns.current_user.current_org_id
    authorize_url = DocuSign.get_authorization_url(organisation_id)

    json(conn, %{
      status: "success",
      redirect_url: authorize_url
    })
  end

  swagger_path :callback do
    get("/docusign/callback")
    summary("Handle DocuSign OAuth callback")
    description("Processes the authorization code returned by DocuSign after user authorization")

    parameters do
      code(:query, :string, "Authorization code from DocuSign", required: true)
    end

    tag("Integrations")

    response(302, "Redirect to homepage")
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Handles the callback from DocuSign after user authorization.

  This endpoint receives the authorization code from DocuSign after the user has authorized
  the application. It exchanges this code for an access token using the code verifier
  that was stored during the initial authorization request.

  The access token and related data are stored in the organization's integration configuration.
  After successful processing, the user is redirected to the homepage.
  """
  @spec callback(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
  def callback(conn, %{"code" => code}) do
    organisation_id = conn.assigns.current_user.current_org_id
    DocuSign.handle_callback(organisation_id, %{"code" => code})

    redirect(conn, to: "/")
  end
end
