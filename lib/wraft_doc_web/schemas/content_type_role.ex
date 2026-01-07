defmodule WraftDocWeb.Schemas.ContentTypeRole do
  @moduledoc """
  Schema for ContentTypeRole request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.{ContentType, Role}

  defmodule ContentTypeRoleRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type role request",
      description: "Request to add a role to a content type",
      type: :object,
      properties: %{
        content_type_id: %Schema{type: :string, description: "ID of the content_type"},
        role_id: %Schema{type: :string, description: "ID of the role type"}
      },
      example: %{
        content_type_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        role_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
      }
    })
  end

  defmodule ContentTypeRoleResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type role response",
      description: "Response after adding a role to a content type",
      type: :object,
      properties: %{
        uuid: %Schema{type: :string, description: "ID of the content_type_role"},
        role: Role.Role,
        content_type: ContentType.RoleContentType
      },
      example: %{
        uuid: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        role: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          name: "Admin",
          description: "Admin role",
          inserted_at: "2023-08-21T14:00:00Z",
          updated_at: "2023-08-21T14:00:00Z"
        },
        content_type: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          name: "Blog Post",
          description: "A blog post content type",
          inserted_at: "2023-08-21T14:00:00Z",
          updated_at: "2023-08-21T14:00:00Z"
        }
      }
    })
  end

  defmodule DeleteContentTypeRole do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Delete Content Type Role",
      description: "Response after deleting a content type role",
      type: :object,
      properties: %{
        uuid: %Schema{type: :string, description: "ID of the content_type_role"}
      },
      example: %{
        uuid: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
      }
    })
  end
end
