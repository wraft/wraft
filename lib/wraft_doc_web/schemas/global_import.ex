defmodule WraftDocWeb.Schemas.GlobalImport do
  @moduledoc """
  Schema for GlobalImport request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule FrameImportResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Frame Import Response",
      description: "Response schema for a successful frame import",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Frame ID"},
        name: %Schema{type: :string, description: "Frame name"},
        description: %Schema{type: :string, description: "Frame description"},
        type: %Schema{type: :string, description: "Frame type"},
        thumbnail: %Schema{type: :string, description: "Thumbnail URL"},
        asset: %Schema{type: :object, description: "Associated asset"},
        fields: %Schema{type: :array, description: "Frame fields"},
        meta: %Schema{type: :object, description: "Wraft JSON metadata"},
        updated_at: %Schema{type: :string, format: "date-time"},
        inserted_at: %Schema{type: :string, format: "date-time"}
      },
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        name: "my-document-frame",
        description: "My document frame",
        type: "zip",
        thumbnail: "https://example.com/thumbnail.png",
        asset: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          name: "frame-asset.zip",
          type: "application/zip"
        },
        fields: [],
        meta: %{
          metadata: %{
            type: "frame",
            name: "my-document-frame"
          }
        },
        inserted_at: "2024-01-15T10:30:00Z",
        updated_at: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule TemplateAssetImportResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Template Asset Import Response",
      description: "Response schema for a successful template asset import",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "Success message"},
        items: %Schema{
          type: :array,
          description: "List of imported items",
          items: %Schema{
            type: :object,
            properties: %{
              item_type: %Schema{
                type: :string,
                description: "Type of item (e.g., 'frame', 'layout')"
              },
              id: %Schema{type: :string, description: "Item ID"},
              name: %Schema{type: :string, description: "Item name (for frames, layouts)"},
              title: %Schema{type: :string, description: "Item title (for data templates)"},
              created_at: %Schema{
                type: :string,
                format: "date-time",
                description: "Creation timestamp"
              }
            }
          }
        }
      },
      example: %{
        message: "Template imported successfully",
        items: [
          %{
            item_type: "frame",
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            name: "Header Frame",
            created_at: "2024-01-15T10:30:00Z"
          },
          %{
            item_type: "layout",
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa7",
            name: "Main Layout",
            created_at: "2024-01-15T10:30:00Z"
          },
          %{
            item_type: "data_template",
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa8",
            title: "Sample Template",
            created_at: "2024-01-15T10:30:00Z"
          }
        ]
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
        data: %Schema{
          type: :object,
          properties: %{
            meta: %Schema{type: :object, description: "Wraft JSON metadata"},
            file_details: %Schema{
              type: :object,
              properties: %{
                file_name: %Schema{type: :string, description: "Name of the file"},
                file_size: %Schema{type: :integer, description: "Size of the file in bytes"},
                file_type: %Schema{type: :string, description: "MIME type of the file"},
                files: %Schema{
                  type: :array,
                  items: %Schema{type: :string},
                  description: "List of files in the archive"
                }
              }
            }
          }
        },
        errors: %Schema{
          type: :array,
          description: "Validation errors",
          items: %Schema{
            type: :object,
            properties: %{
              type: %Schema{type: :string, description: "Error type"},
              message: %Schema{type: :string, description: "Error message"}
            }
          }
        }
      },
      example: %{
        data: %{
          meta: %{
            metadata: %{
              type: "frame",
              name: "example-frame",
              description: "Example frame"
            }
          },
          file_details: %{
            file_name: "example.zip",
            file_size: 123_456,
            file_type: "application/zip",
            files: ["assets/logo.svg", "template.typst", "default.typst"]
          }
        },
        errors: [
          %{
            type: "file_validation_error",
            message: "Invalid file structure"
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
        message: %Schema{type: :string, description: "Validation message"},
        result: %Schema{type: :object, description: "Validation result (optional)"}
      },
      example: %{
        message: "Validation completed successfully"
      }
    })
  end

  defmodule GlobalImportResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Global Import Response",
      description:
        "Response schema for a successful global file import (can be frame or template asset)",
      oneOf: [
        FrameImportResponse,
        TemplateAssetImportResponse
      ]
    })
  end
end
