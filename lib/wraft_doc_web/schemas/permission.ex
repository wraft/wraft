defmodule WraftDocWeb.Schemas.Permission do
  @moduledoc """
  Schema for Permission request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Permission do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "A permission JSON response",
      description: "JSON response for a permission",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the permission"},
        name: %Schema{type: :string, description: "Permissions's name"},
        action: %Schema{type: :string, description: "Permission's action"}
      },
      required: [:id, :name, :action],
      example: %{
        id: "1232148nb3478",
        name: "layout:index",
        action: "Index",
        resource: "Layout"
      }
    })
  end

  defmodule PermissionByResource do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Permissions by resource",
      description: "Permissions grouped by resource",
      type: :object,
      additionalProperties: %Schema{type: :array, items: Permission},
      example: %{
        "Layout" => [
          %{id: "1232148nb3478", name: "layout:index", action: "Index"},
          %{id: "2374679278373", name: "layout:manage", action: "Manage"}
        ]
      }
    })
  end

  defmodule ResourceIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Resources index",
      description: "All resources we have in Wraft",
      type: :array,
      items: %Schema{type: :string},
      example: ["Layout", "Content Type", "Data Template"]
    })
  end
end
