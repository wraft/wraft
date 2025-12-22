defmodule WraftDocWeb.Schemas.Asset do
  @moduledoc """
  Schema for Asset request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.User

  defmodule Asset do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Asset",
      description: "An asset.",
      type: :object,
      required: [:id],
      properties: %{
        id: %Schema{type: :string, description: "The ID of the asset"},
        name: %Schema{type: :string, description: "Name of the asset"},
        type: %Schema{type: :string, description: "Type of the asset - layout or theme"},
        file: %Schema{type: :string, description: "URL of the uploaded file"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the engine inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the engine last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "1232148nb3478",
        name: "Asset",
        type: "layout",
        file: "/signature.pdf",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ShowAsset do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show asset",
      description: "An asset and its details",
      type: :object,
      properties: %{
        content: Asset,
        creator: User.User
      },
      example: %{
        asset: %{
          id: "1232148nb3478",
          name: "Asset",
          type: "layout",
          file: "/signature.pdf",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        creator: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule AssetsIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Assets Index",
      description: "List of assets",
      type: :object,
      properties: %{
        assets: %Schema{type: :array, items: Asset},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        assets: [
          %{
            id: "1232148nb3478",
            name: "Asset",
            type: "layout",
            file: "/signature.pdf",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end
end
