defmodule WraftDocWeb.Schemas.Repository do
  @moduledoc """
  Schema for Repository request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule StorageItem do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Storage Item",
      description: "A file or folder in the storage system.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "The ID of the storage item"},
        name: %Schema{type: :string, description: "Name of the item"},
        display_name: %Schema{type: :string, description: "Display name of the item"},
        item_type: %Schema{type: :string, enum: ["file", "folder"], description: "Type of item"},
        path: %Schema{type: :string, description: "Path to the item"},
        mime_type: %Schema{type: :string, description: "MIME type of the item"},
        size: %Schema{type: :integer, description: "Size in bytes"},
        is_folder: %Schema{type: :boolean, description: "Whether the item is a folder"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Creation timestamp"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Last update timestamp"
        }
      },
      required: [:id, :name],
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "contract.pdf",
        display_name: "Contract Agreement",
        item_type: "file",
        path: "/Contracts/Q4",
        mime_type: "application/pdf",
        size: 1024,
        is_folder: false,
        inserted_at: "2023-01-10T14:00:00Z",
        updated_at: "2023-01-12T09:15:00Z"
      }
    })
  end

  defmodule Repository do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Repository",
      description: "A storage repository containing files and folders.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "The ID of the repository"},
        name: %Schema{type: :string, description: "Name of the repository"},
        description: %Schema{type: :string, description: "Description of the repository"},
        status: %Schema{
          type: :string,
          enum: ["active", "inactive"],
          description: "Status of the repository"
        },
        storage_limit: %Schema{type: :integer, description: "Storage limit in bytes"},
        current_storage_used: %Schema{
          type: :integer,
          description: "Current storage used in bytes"
        },
        item_count: %Schema{type: :integer, description: "Number of items in the repository"},
        creator_id: %Schema{
          type: :string,
          format: :uuid,
          description: "ID of the user who created the repository"
        },
        organisation_id: %Schema{
          type: :string,
          format: :uuid,
          description: "ID of the organisation this repository belongs to"
        },
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Creation timestamp"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Last update timestamp"
        }
      },
      required: [:id, :name],
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "My Documents",
        description: "My personal storage repository",
        status: "active",
        storage_limit: 104_857_600,
        current_storage_used: 52_428_800,
        item_count: 100,
        creator_id: "550e8400-e29b-41d4-a716-446655440000",
        organisation_id: "550e8400-e29b-41d4-a716-446655440000",
        inserted_at: "2023-01-10T14:00:00Z",
        updated_at: "2023-01-12T09:15:00Z"
      }
    })
  end

  defmodule RepositoryCreateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Repository Create Parameters",
      description: """
      Parameters for creating a new repository.

      Required fields:
      - name: Must be unique within the organization
      - storage_limit: In bytes (1GB = 1073741824 bytes)
      """,
      type: :object,
      properties: %{
        name: %Schema{
          type: :string,
          description: "Name of the repository",
          example: "Legal Documents"
        },
        description: %Schema{
          type: :string,
          description: "Description of the repository",
          example: "All legal contracts"
        },
        storage_limit: %Schema{
          type: :integer,
          description: "Storage limit in bytes",
          example: 107_374_182_400
        },
        status: %Schema{
          type: :string,
          enum: ["active", "inactive"],
          default: "active",
          example: "active",
          description: "Status of the repository"
        }
      },
      required: [:name],
      example: %{
        name: "Legal Documents",
        description: "All legal contracts and agreements",
        storage_limit: 107_374_182_400,
        status: "active"
      }
    })
  end

  defmodule RepositoryUpdateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Repository Update Parameters",
      description: "Parameters for updating an existing repository",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the repository"},
        description: %Schema{type: :string, description: "Description of the repository"},
        storage_limit: %Schema{type: :integer, description: "Storage limit in bytes"},
        status: %Schema{
          type: :string,
          enum: ["active", "inactive"],
          description: "Status of the repository"
        }
      },
      example: %{
        name: "Updated Repository Name",
        description: "Updated description",
        storage_limit: 209_715_200,
        status: "active"
      }
    })
  end

  defmodule RepositoriesList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Repositories List",
      description: "List of repositories",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Repository, description: "List of repositories"}
      },
      example: %{
        data: [
          %{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "Company Documents",
            description: "Official company documents",
            status: "active",
            storage_limit: 107_374_182_400,
            current_storage_used: 32_212_254_720,
            item_count: 1250,
            creator_id: "550e8400-e29b-41d4-a716-446655440000",
            organisation_id: "550e8400-e29b-41d4-a716-446655440000",
            inserted_at: "2023-03-15T09:30:00Z",
            updated_at: "2023-06-20T14:22:00Z"
          }
        ]
      }
    })
  end

  defmodule CounterParty do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Counter Party",
      description: "A counter party entity",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "The ID of the counter party"},
        name: %Schema{type: :string, description: "Name of the counter party"},
        email: %Schema{type: :string, description: "Email of the counter party"},
        type: %Schema{
          type: :string,
          enum: ["individual", "organization"],
          description: "Type of counter party"
        },
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Creation timestamp"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Last update timestamp"
        }
      },
      required: [:id, :name],
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "ABC Corporation",
        email: "contact@abc.com",
        type: "organization",
        inserted_at: "2023-01-10T14:00:00Z",
        updated_at: "2023-01-12T09:15:00Z"
      }
    })
  end

  defmodule CounterPartiesList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Counter Parties List",
      description: "List of counter parties",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: CounterParty, description: "List of counter parties"},
        total: %Schema{type: :integer, description: "Total number of counter parties"},
        page: %Schema{type: :integer, description: "Current page number"},
        per_page: %Schema{type: :integer, description: "Items per page"}
      },
      example: %{
        data: [
          %{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "ABC Corporation",
            email: "contact@abc.com",
            type: "organization"
          }
        ],
        total: 1,
        page: 1,
        per_page: 10
      }
    })
  end

  defmodule CreateSignatureRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Create Signature Request",
      description: "Parameters for creating a signature request",
      type: :object,
      properties: %{
        document_id: %Schema{
          type: :string,
          format: :uuid,
          description: "ID of the document to be signed"
        },
        signer_email: %Schema{type: :string, description: "Email of the signer"},
        signer_name: %Schema{type: :string, description: "Name of the signer"},
        message: %Schema{
          type: :string,
          description: "Message to include with the signature request"
        },
        due_date: %Schema{
          type: :string,
          format: "date-time",
          description: "Due date for the signature"
        },
        signature_type: %Schema{
          type: :string,
          enum: ["electronic", "digital"],
          default: "electronic",
          description: "Type of signature"
        }
      },
      required: [:document_id, :signer_email, :signer_name],
      example: %{
        document_id: "550e8400-e29b-41d4-a716-446655440000",
        signer_email: "john.doe@example.com",
        signer_name: "John Doe",
        message: "Please sign this document",
        due_date: "2023-12-31T23:59:59Z",
        signature_type: "electronic"
      }
    })
  end
end
