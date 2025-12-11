defmodule WraftDocWeb.Schemas.StorageAsset do
  @moduledoc """
  Schema for StorageAsset request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule StorageAsset do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Asset",
      description: "A physical storage asset representing an uploaded file.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the storage asset", format: "uuid"},
        filename: %Schema{type: :string, description: "Original filename"},
        storage_key: %Schema{type: :string, description: "Storage system key"},
        storage_backend: %Schema{type: :string, description: "Storage backend identifier"},
        file_size: %Schema{type: :integer, description: "File size in bytes"},
        mime_type: %Schema{type: :string, description: "MIME type of the file"},
        processing_status: %Schema{
          type: :string,
          description: "Processing status",
          enum: ["pending", "processing", "completed", "failed"]
        },
        upload_completed_at: %Schema{
          type: :string,
          description: "Upload completion timestamp",
          format: "ISO-8601"
        },
        checksum_sha256: %Schema{type: :string, description: "File checksum"},
        thumbnail_path: %Schema{type: :string, description: "Path to generated thumbnail"},
        preview_path: %Schema{type: :string, description: "Path to generated preview"},
        inserted_at: %Schema{type: :string, description: "Creation timestamp", format: "ISO-8601"},
        updated_at: %Schema{
          type: :string,
          description: "Last update timestamp",
          format: "ISO-8601"
        },
        url: %Schema{type: :string, description: "Access URL for the asset"}
      },
      required: [:id, :filename, :storage_key],
      example: %{
        id: "650e8400-e29b-41d4-a716-446655440000",
        filename: "contract.pdf",
        storage_key: "uploads/contract.pdf",
        storage_backend: "s3",
        file_size: 1024,
        mime_type: "application/pdf",
        processing_status: "completed",
        upload_completed_at: "2023-01-15T10:30:00Z",
        checksum_sha256: "a1b2c3...",
        thumbnail_path: "thumbnails/contract.jpg",
        preview_path: "previews/contract.html",
        inserted_at: "2023-01-15T10:25:00Z",
        updated_at: "2023-01-15T10:30:00Z",
        url: "https://storage.example.com/uploads/contract.pdf"
      }
    })
  end

  defmodule StorageAssetList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Asset List",
      description: "A list of storage assets",
      type: :array,
      items: StorageAsset
    })
  end

  defmodule StorageAssetCreateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Asset Creation Parameters",
      description: "Parameters for creating a storage asset (legacy endpoint)",
      type: :object,
      properties: %{
        filename: %Schema{type: :string, description: "Original filename"},
        storage_key: %Schema{type: :string, description: "Storage system key"},
        file_size: %Schema{type: :integer, description: "File size in bytes"},
        mime_type: %Schema{type: :string, description: "MIME type of the file"}
      },
      required: [:filename, :storage_key],
      example: %{
        filename: "contract.pdf",
        storage_key: "uploads/contract.pdf",
        file_size: 1024,
        mime_type: "application/pdf"
      }
    })
  end

  defmodule FileUploadParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "File Upload Parameters",
      description: "Parameters for uploading a new file",
      type: :object,
      properties: %{
        file: %Schema{type: :string, format: :binary, description: "The file to upload"},
        parent_id: %Schema{type: :string, format: :uuid, description: "Parent folder ID"},
        repository_id: %Schema{type: :string, format: :uuid, description: "Repository ID"},
        display_name: %Schema{type: :string, description: "Custom display name"},
        classification_level: %Schema{
          type: :string,
          description: "Security classification level",
          enum: ["public", "internal", "confidential", "secret"]
        }
      },
      required: [:file],
      example: %{
        parent_id: "550e8400-e29b-41d4-a716-446655440000",
        repository_id: "550e8400-e29b-41d4-a716-446655440001",
        display_name: "Contract Agreement",
        classification_level: "confidential"
      }
    })
  end

  defmodule FileUploadResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "File Upload Response",
      description: "Successful file upload response",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          description: "Created storage item with assets",
          properties: %{
            id: %Schema{
              type: :string,
              format: :uuid,
              example: "550e8400-e29b-41d4-a716-446655440000"
            },
            name: %Schema{type: :string, example: "contract.pdf"},
            display_name: %Schema{type: :string, example: "Contract Agreement"},
            item_type: %Schema{type: :string, example: "file"},
            path: %Schema{type: :string, example: "/Contracts/Q3"},
            mime_type: %Schema{type: :string, example: "application/pdf"},
            size: %Schema{type: :integer, example: 1024},
            assets: %Schema{type: :array, items: StorageAsset}
          }
        }
      },
      example: %{
        "data" => %{
          "id" => "550e8400-e29b-41d4-a716-446655440000",
          "name" => "contract.pdf",
          "display_name" => "Contract Agreement",
          "item_type" => "file",
          "path" => "/Contracts/Q3",
          "mime_type" => "application/pdf",
          "size" => 1024,
          "assets" => [
            %{
              "id" => "650e8400-e29b-41d4-a716-446655440000",
              "filename" => "contract.pdf",
              "storage_key" => "uploads/2023/contract.pdf",
              "file_size" => 1024,
              "mime_type" => "application/pdf"
            }
          ]
        }
      }
    })
  end
end
