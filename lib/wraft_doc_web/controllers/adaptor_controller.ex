defmodule WraftDocWeb.Api.V1.AdaptorController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
       [roles: [:creator], create_new: true]
       when action in [:index]

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Workflows.Adaptors.Registry

  swagger_path :index do
    get("/adaptors")
    summary("List available adaptors")
    description("Returns list of all available workflow adaptors")

    response(200, "Success")
    response(401, "Unauthorized")
  end

  def index(conn, _params) do
    adaptors = Registry.list_adaptors()

    # Map adaptor names to their metadata
    adaptor_list =
      Enum.map(adaptors, fn adaptor_name ->
        %{
          name: adaptor_name,
          label: format_label(adaptor_name),
          description: get_description(adaptor_name)
        }
      end)

    render(conn, "index.json", adaptors: adaptor_list)
  end

  defp format_label(name) do
    case name do
      "condition" -> "Condition"
      "template" -> "Template"
      "http" -> "HTTP Request"
      "database" -> "Database"
      _ -> String.capitalize(name)
    end
  end

  defp get_description(name) do
    case name do
      "condition" -> "Evaluate data and branch workflow"
      "template" -> "Generate documents from templates"
      "http" -> "Make HTTP API calls"
      "database" -> "Query or update database"
      _ -> "Custom adaptor"
    end
  end
end
