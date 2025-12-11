defmodule WraftDocWeb.Schemas.ContentTypeRole do
  @moduledoc """
  Schema for ContentTypeRole request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ContentTypeRole do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Content type role",
      description: "List of roles under content type",
      type: :object,
      properties: %{
        content_type_id: %Schema{type: :string, description: "ID of the content_type"},
        role_id: %Schema{type: :string, description: "ID of the role type"}
      }
    })
  end

  defmodule DeleteContentTypeRole do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Delete Content Type",
      description: "delete a content type role",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the content_type_role"}
      }
    })
  end
end
