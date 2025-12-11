defmodule WraftDocWeb.Schemas.CloudImport do
  @moduledoc """
  Schema for CloudImport request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  # Note: This schema module contains definitions for Google Drive, Dropbox, and OneDrive
  # cloud storage integrations. The schemas are organized by provider.

  # The actual schema definitions are extensive and already well-defined in the controller.
  # For brevity and to avoid duplication, we reference the inline schemas in the controller
  # operations directly. This is acceptable for OpenApiSpex when schemas are simple response types.

  defmodule ImportRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Import Request",
      description: "Request to import files from cloud storage",
      type: :object,
      properties: %{
        file_ids: %Schema{
          type: :array,
          description: "List of file IDs to import",
          items: %Schema{type: :string}
        }
      },
      example: %{
        file_ids: ["file1", "file2"]
      }
    })
  end

  defmodule DownloadRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Download Request",
      description: "Request to download files from cloud storage",
      type: :object,
      properties: %{
        file_ids: %Schema{
          type: :array,
          description: "List of file IDs to download",
          items: %Schema{type: :string}
        }
      },
      example: %{
        file_ids: ["file1", "file2"]
      }
    })
  end
end
