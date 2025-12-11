defmodule WraftDocWeb.Schemas.GlobalImport do
  @moduledoc """
  Schema for GlobalImport request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule GlobalImportResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Global Import Response",
      description: "Response schema for a successful global file import",
      type: :object,
      properties: %{
        frame: WraftDocWeb.Schemas.Frame.Frame,
        template_asset: WraftDocWeb.Schemas.TemplateAsset.TemplateAsset
      }
    })
  end

  defmodule GlobalPreImportResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Global Pre Import Response",
      description: "Response schema for a successful global file pre-import",
      type: :object,
      properties: %{
        meta: %Schema{type: :object, description: "Wraft JSON"},
        file_details: %Schema{type: :object, description: "File details"},
        errors: %Schema{
          type: :array,
          description: "Errors",
          items: %Schema{type: :string}
        }
      },
      example: %{
        file_details: %{
          file_name: "example.zip",
          file_size: 123_456,
          file_type: "application/zip",
          files: ["assets/logo.svg", "template.typst", "default.typst"]
        },
        meta: %{},
        errors: [
          %{
            type: "File_validation",
            error: "Invalid file"
          }
        ]
      }
    })
  end

  defmodule GlobalFileValidationResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Global File Validation Response",
      description: "Response for global file validation",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "Validation message"}
      },
      example: %{
        message: "Validation completed successfully"
      }
    })
  end
end
