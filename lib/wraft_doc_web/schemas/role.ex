defmodule WraftDocWeb.Schemas.Role do
  @moduledoc """
  Schema for Role request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule RoleRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Role request",
      description: "Create role request",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Role name"},
        permissions: %Schema{
          type: :array,
          description: "Permissions of the role",
          items: %Schema{type: :string}
        }
      },
      required: [:name],
      example: %{
        name: "Editor",
        permissions: ["layout:index", "layout:show", "layout:create", "layout:update"]
      }
    })
  end

  defmodule Role do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type under Role",
      description: "all the content type under the role",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Id of the role"},
        name: %Schema{type: :string, description: "Name of the role"},
        permissions: %Schema{
          type: :array,
          description: "Permissions of the role",
          items: %Schema{type: :string}
        }
      },
      example: %{
        id: "9322d1a5-4f44-463d-b4a5-ce797a029ac2",
        name: "Editor",
        permissions: ["layout:index", "layout:show", "layout:create", "layout:update"]
      }
    })
  end

  defmodule ListOfRoles do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Roles array",
      description: "List of existing Roles",
      type: :array,
      items: Role
    })
  end

  defmodule AssignRole do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Assign Role",
      description: "Response for assign user role",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Response Info"}
      },
      example: %{
        info: "Assigned the given role to the user successfully.!"
      }
    })
  end

  defmodule UnassignRole do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Unassign Role",
      description: "Response for unassigning user role",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Response Info"}
      },
      example: %{
        info: "Unassigned the given role for the user successfully.!"
      }
    })
  end
end
