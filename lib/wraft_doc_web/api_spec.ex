defmodule WraftDocWeb.ApiSpec do
  @moduledoc """
  API spec for Wraft Docs
  """
  alias OpenApiSpex.Components
  alias OpenApiSpex.Info
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.SecurityScheme
  alias OpenApiSpex.Server

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
        title: "Wraft",
        version: to_string(Application.spec(:wraft_doc, :vsn))
      },
      # Populate the paths from a phoenix router
      paths: OpenApiSpex.Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description: """
            JWT-based authentication.
            - Pass the token in the `Authorization` header as `Bearer <token>`.
            """
          },
          "x-api-key" => %SecurityScheme{
            type: "apiKey",
            in: "header",
            name: "x-api-key",
            description: """
            API key based authentication.
            - Include `x-api-key` in the request headers.
            """
          }
        }
      },
      security: [
        %{"authorization" => []},
        %{"x-api-key" => []}
      ],
      tags: [
        %OpenApiSpex.Tag{name: "Health", description: "Health check operations"},
        %OpenApiSpex.Tag{name: "User", description: "User operations"},
        %OpenApiSpex.Tag{name: "Profile", description: "Profile operations"},
        %OpenApiSpex.Tag{name: "Organisation", description: "Organisation operations"},
        %OpenApiSpex.Tag{name: "Registration", description: "Registration operations"},
        %OpenApiSpex.Tag{name: "Instance", description: "Core instance operations"},
        %OpenApiSpex.Tag{name: "Instance Approval", description: "Approval workflows"},
        %OpenApiSpex.Tag{name: "Instance Approval System", description: "System approvals"},
        %OpenApiSpex.Tag{name: "Instance Guests", description: "Guest access"}
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
