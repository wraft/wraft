defmodule WraftDocWeb.Schemas.RoleGroup do
  @moduledoc """
  Schema for RoleGroup request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule RoleGroupRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Role group request",
      description: "Role group details",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Role group name"},
        description: %Schema{type: :string, description: "Role group description"},
        roles: %Schema{
          type: :array,
          description: "Lists of role id s",
          items: %Schema{type: :string}
        }
      },
      required: [:name],
      example: %{
        name: "Chatura",
        description: "Team containg 4 roles on management",
        group_roles: [
          %{role_id: "sdfsdf-541sdfsd-2256sdf1-1221sd5f"},
          %{role_id: "sdfsdf-541sdfsd-2256sdf1-1221sd5f"},
          %{role_id: "sdfsdf-541sdfsd-2256sdf1-1221sd5f"}
        ]
      }
    })
  end

  defmodule RoleGroup do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Role group",
      description: "Role group details",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Role group name"},
        description: %Schema{type: :string, description: "Role group description"},
        roles: %Schema{type: :array, description: "List of roles", items: %Schema{type: :object}},
        inserted_at: %Schema{type: :string, description: "inserted at"},
        updated_at: %Schema{type: :string, description: "Updated at"}
      },
      example: %{
        name: "Chatura",
        description: "Team containg 4 roles on management",
        roles: [
          %{name: "manager"},
          %{name: "CTO"},
          %{name: "CEO"}
        ]
      }
    })
  end

  defmodule RoleGroups do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Role group list",
      type: :array,
      items: RoleGroup
    })
  end

  defmodule RoleGroupIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Role group index",
      type: :object,
      properties: %{
        role_groups: RoleGroups
      },
      example: %{
        role_groups: [
          %{name: "Chatura", description: "Team containg 4 roles on management"},
          %{name: "Chatura", description: "Team containg 4 roles on management"}
        ]
      }
    })
  end
end
