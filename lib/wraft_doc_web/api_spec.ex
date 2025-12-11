defmodule WraftDocWeb.ApiSpec do
  @moduledoc """
  API spec for Wraft Docs
  """
  alias OpenApiSpex.{Components, Info, OpenApi, Server}
  alias WraftDocWeb.Endpoint
  alias WraftDocWeb.Router

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    config = %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Wraft Docs",
        version: "0.0.1"
      },
      # Populate the paths from a phoenix router
      paths: OpenApiSpex.Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "authorization" => %{
            type: "apiKey",
            name: "Authorization",
            in: "header"
          },
          "x-api-key" => %{
            type: "apiKey",
            name: "X-API-Key",
            in: "header"
          }
        }
      },
      security: [
        %{"authorization" => []},
        %{"x-api-key" => []}
      ],
      tags: [
        %OpenApiSpex.Tag{name: "Instance", description: "Core instance operations"},
        %OpenApiSpex.Tag{name: "Instance Approval", description: "Approval workflows"},
        %OpenApiSpex.Tag{name: "Instance Approval System", description: "System approvals"},
        %OpenApiSpex.Tag{name: "InstanceGuests", description: "Guest access"}
      ]
    }

    config
    |> Map.put(:"x-tagGroups", [
      %{
        name: "Instance",
        tags: ["Instance", "Instance Approval", "Instance Approval System", "InstanceGuests"]
      }
    ])
    |> OpenApiSpex.resolve_schema_modules()
  end
end
