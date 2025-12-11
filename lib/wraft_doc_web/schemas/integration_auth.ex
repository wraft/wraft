defmodule WraftDocWeb.Schemas.IntegrationAuth do
  @moduledoc """
  Schema for IntegrationAuth request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule AuthUrlResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Authorization URL Response",
      description: "Response containing the DocuSign authorization URL",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Status of the request", example: "success"},
        redirect_url: %Schema{
          type: :string,
          description: "URL to redirect the user for DocuSign authorization"
        }
      },
      required: [:status, :redirect_url],
      example: %{
        status: "success",
        redirect_url:
          "https://account-d.docusign.com/oauth/auth?response_type=code&scope=signature&..."
      }
    })
  end
end
