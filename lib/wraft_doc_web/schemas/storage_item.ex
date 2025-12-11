defmodule WraftDocWeb.Schemas.StorageItem do
  @moduledoc """
  Schema for StorageItem request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule StorageItem do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Item",
      description: "A file or folder in the storage system",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the storage item", format: "uuid"},
        name: %Schema{type: :string, description: "Name of the item"},
        display_name: %Schema{type: :string, description: "Display name of the item"},
        item_type: %Schema{type: :string, description: "Type of item", enum: ["file", "folder"]},
        path: %Schema{type: :string, description: "Path to the item"},
        mime_type: %Schema{type: :string, description: "MIME type of the item"},
        file_extension: %Schema{type: :string, description: "File extension"},
        size: %Schema{type: :integer, description: "Size in bytes"},
        is_folder: %Schema{type: :boolean, description: "Whether the item is a folder"},
        depth_level: %Schema{type: :integer, description: "Depth level in the folder hierarchy"},
        materialized_path: %Schema{type: :string, description: "Materialized path for hierarchy"},
        version_number: %Schema{type: :integer, description: "Version number of the item"},
        is_current_version: %Schema{
          type: :boolean,
          description: "Whether this is the current version"
        },
        classification_level: %Schema{type: :string, description: "Security classification level"},
        content_extracted: %Schema{
          type: :boolean,
          description: "Whether content has been extracted"
        },
        thumbnail_generated: %Schema{
          type: :boolean,
          description: "Whether thumbnail has been generated"
        },
        download_count: %Schema{type: :integer, description: "Number of times downloaded"},
        last_accessed_at: %Schema{
          type: :string,
          description: "Last access timestamp",
          format: "ISO-8601"
        },
        metadata: %Schema{type: :object, description: "Additional metadata"},
        parent_id: %Schema{type: :string, description: "ID of parent folder", format: "uuid"},
        repository_id: %Schema{type: :string, description: "ID of the repository", format: "uuid"},
        creator_id: %Schema{type: :string, description: "ID of the creator", format: "uuid"},
        organisation_id: %Schema{
          type: :string,
          description: "ID of the organisation",
          format: "uuid"
        },
        inserted_at: %Schema{type: :string, description: "Creation timestamp", format: "ISO-8601"},
        updated_at: %Schema{
          type: :string,
          description: "Last update timestamp",
          format: "ISO-8601"
        },
        assets: %Schema{
          type: :array,
          description: "Associated storage assets",
          items: WraftDocWeb.Schemas.StorageAsset.StorageAsset
        }
      },
      required: [:id, :name],
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "contract.pdf",
        display_name: "Contract Agreement",
        item_type: "file",
        path: "/Contracts/Q4/contract.pdf",
        mime_type: "application/pdf",
        file_extension: "pdf",
        size: 1_024_000,
        is_folder: false,
        depth_level: 2,
        materialized_path: "/Contracts/Q4/",
        version_number: 1,
        is_current_version: true,
        classification_level: "public",
        content_extracted: true,
        thumbnail_generated: true,
        download_count: 5,
        last_accessed_at: "2023-01-15T10:30:00Z",
        metadata: %{},
        parent_id: "550e8400-e29b-41d4-a716-446655440001",
        repository_id: "550e8400-e29b-41d4-a716-446655440002",
        creator_id: "550e8400-e29b-41d4-a716-446655440003",
        organisation_id: "550e8400-e29b-41d4-a716-446655440004",
        inserted_at: "2023-01-10T14:00:00Z",
        updated_at: "2023-01-12T09:15:00Z",
        assets: []
      }
    })
  end

  defmodule Breadcrumb do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Breadcrumb",
      description: "Navigation breadcrumb item",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the folder", format: "uuid"},
        name: %Schema{type: :string, description: "Name of the folder"},
        path: %Schema{type: :string, description: "Path to the folder"},
        is_folder: %Schema{type: :boolean, description: "Whether this is a folder", default: true}
      },
      required: [:name],
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "Documents",
        path: "/Documents",
        is_folder: true
      }
    })
  end

  defmodule CurrentFolder do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Current Folder",
      description: "Information about the current folder",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the folder", format: "uuid"},
        name: %Schema{type: :string, description: "Name of the folder"},
        is_folder: %Schema{type: :boolean, description: "Whether this is a folder", default: true},
        path: %Schema{type: :string, description: "Path to the folder"},
        materialized_path: %Schema{type: :string, description: "Materialized path"}
      },
      required: [:name],
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "Documents",
        is_folder: true,
        path: "/Documents",
        materialized_path: "/Documents/"
      }
    })
  end

  defmodule ListMeta do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "List Metadata",
      description: "Metadata for list responses",
      type: :object,
      properties: %{
        count: %Schema{type: :integer, description: "Number of items returned"},
        breadcrumbs_count: %Schema{type: :integer, description: "Number of breadcrumb items"},
        sort_by: %Schema{type: :string, description: "Sort field used"},
        sort_order: %Schema{type: :string, description: "Sort order used"},
        timestamp: %Schema{type: :string, description: "Response timestamp", format: "ISO-8601"}
      },
      example: %{
        count: 25,
        breadcrumbs_count: 3,
        sort_by: "created",
        sort_order: "desc",
        timestamp: "2023-01-15T10:30:00Z"
      }
    })
  end

  defmodule StorageItemsList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Items List",
      description: "List of storage items with metadata",
      type: :object,
      properties: %{
        data: %Schema{type: :array, description: "List of storage items", items: StorageItem},
        current_folder: CurrentFolder,
        meta: ListMeta
      },
      example: %{
        data: [
          %{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "Documents",
            is_folder: true,
            size: 0,
            mime_type: "inode/directory"
          }
        ],
        breadcrumbs: [
          %{id: "root", name: "Root", path: "/"}
        ],
        current_folder: %{
          id: "550e8400-e29b-41d4-a716-446655440000",
          name: "Documents",
          is_folder: true
        },
        meta: %{
          count: 1,
          sort_by: "created",
          sort_order: "desc"
        }
      }
    })
  end

  defmodule StorageItemCreateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Item Create Parameters",
      description: "Parameters for creating a storage item",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the item"},
        display_name: %Schema{type: :string, description: "Display name of the item"},
        item_type: %Schema{type: :string, description: "Type of item", enum: ["file", "folder"]},
        path: %Schema{type: :string, description: "Path to the item"},
        mime_type: %Schema{type: :string, description: "MIME type of the item"},
        size: %Schema{type: :integer, description: "Size in bytes", default: 0},
        parent_id: %Schema{type: :string, description: "ID of parent folder", format: "uuid"},
        metadata: %Schema{type: :object, description: "Additional metadata"}
      },
      required: [:name, :item_type],
      example: %{
        name: "new_document.pdf",
        display_name: "New Document",
        item_type: "file",
        path: "/Documents/new_document.pdf",
        mime_type: "application/pdf",
        size: 1_024_000,
        parent_id: "550e8400-e29b-41d4-a716-446655440000",
        metadata: %{}
      }
    })
  end

  defmodule FolderCreateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Folder Create Parameters",
      description: "Parameters for creating a folder",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the folder"},
        path: %Schema{type: :string, description: "Path to the folder"},
        parent_id: %Schema{type: :string, description: "ID of parent folder", format: "uuid"}
      },
      required: [:name, :path],
      example: %{
        name: "New Folder",
        path: "/Documents/New Folder",
        parent_id: "550e8400-e29b-41d4-a716-446655440000"
      }
    })
  end

  defmodule StorageItemUpdateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Item Update Parameters",
      description: "Parameters for updating a storage item",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the item"},
        display_name: %Schema{type: :string, description: "Display name of the item"},
        metadata: %Schema{type: :object, description: "Additional metadata"}
      },
      example: %{
        name: "updated_document.pdf",
        display_name: "Updated Document",
        metadata: %{category: "contracts"}
      }
    })
  end

  defmodule RenameParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Rename Parameters",
      description: "Parameters for renaming a storage item",
      type: :object,
      properties: %{
        new_name: %Schema{type: :string, description: "New name for the item"}
      },
      required: [:new_name],
      example: %{
        new_name: "renamed_document.pdf"
      }
    })
  end

  defmodule NavigationItems do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Navigation Items",
      description: "Items and breadcrumbs for navigation",
      type: :object,
      properties: %{
        items: %Schema{type: :array, description: "List of storage items", items: StorageItem}
      },
      example: %{
        items: [],
        breadcrumbs: []
      }
    })
  end

  defmodule NavigationData do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Navigation Data",
      description: "Storage navigation data",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          description: "Navigation items and breadcrumbs",
          anyOf: [NavigationItems]
        },
        meta: ListMeta
      },
      example: %{
        data: %{
          items: [],
          breadcrumbs: []
        },
        meta: %{
          count: 0,
          timestamp: "2023-01-15T10:30:00Z"
        }
      }
    })
  end

  defmodule DeleteStorageItemResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Delete Storage Item Response",
      description: "Response for successful storage item deletion",
      type: :object,
      properties: %{
        message: %Schema{
          type: :string,
          description: "Success message",
          example: "Storage item marked for deletion"
        },
        id: %Schema{
          type: :string,
          description: "ID of deleted item",
          format: "uuid",
          example: "550e8400-e29b-41d4-a716-446655440000"
        }
      }
    })
  end
end
