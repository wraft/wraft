defmodule WraftDocWeb.Schemas.InstanceGuest do
  @moduledoc """
  Schema for InstanceGuest request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule InviteDocumentRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Share document request",
      description: "Request to share a document",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email"},
        role: %Schema{type: :string, description: "Role", enum: ["suggestor", "viewer"]}
      },
      required: [:email, :role],
      example: %{
        "email" => "example@example.com",
        "role" => "suggestor"
      }
    })
  end

  defmodule VerifyDocumentInviteTokenResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Verify document invite token response",
      description: "Response for document invite token verification",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Token"},
        role: %Schema{type: :string, description: "Role"},
        user: WraftDocWeb.Schemas.User.User
      },
      example: %{
        token: "1232148nb3478",
        role: "suggestor",
        user: %{
          id: "6529b52b-071c-4b82-950c-539b73b8833e",
          name: "John Doe",
          email: "john@example.com",
          is_guest: false,
          email_verified: true,
          inserted_at: "2023-04-23T10:00:00Z",
          updated_at: "2023-04-23T10:00:00Z"
        }
      }
    })
  end

  defmodule Collaborator do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Collaborator",
      description: "A collaborator",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Id"},
        name: %Schema{type: :string, description: "Name"},
        email: %Schema{type: :string, description: "Email"},
        role: %Schema{type: :string, description: "Role"},
        status: %Schema{type: :string, description: "Status"},
        created_at: %Schema{type: :string, description: "Created at"},
        updated_at: %Schema{type: :string, description: "Updated at"}
      },
      example: %{
        id: "6529b52b-071c-4b82-950c-539b73b8833e",
        name: "John Doe",
        email: "john@example.com",
        role: "viewer",
        status: "active",
        created_at: "2023-04-23T10:00:00Z",
        updated_at: "2023-04-23T10:00:00Z"
      }
    })
  end

  defmodule CounterPartiesRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Counter parties request",
      description: "Request to create counter parties",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name"},
        guest_user_id: %Schema{type: :string, description: "Guest user id"}
      },
      required: [:name, :guest_user_id],
      example: %{
        name: "John Doe",
        guest_user_id: "1232148nb3478"
      }
    })
  end

  defmodule CounterPartiesResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Counter parties response",
      description: "Response for counter parties",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Id"},
        name: %Schema{type: :string, description: "Name"},
        guest_user_id: %Schema{type: :string, description: "Guest user id"},
        content: WraftDocWeb.Schemas.Content.Content,
        created_at: %Schema{type: :string, description: "Created at"},
        updated_at: %Schema{type: :string, description: "Updated at"}
      },
      example: %{
        id: "6529b52b-071c-4b82-950c-539b73b8833e",
        name: "John Doe",
        guest_user_id: "1232148nb3478",
        content: %{
          id: "1232148nb3478",
          instance_id: "OFFL01",
          raw: "Content",
          serialized: %{title: "Title of the content", body: "Body of the content"},
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        created_at: "2023-04-23T10:00:00Z",
        updated_at: "2023-04-23T10:00:00Z"
      }
    })
  end

  defmodule ShareDocumentRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Share document request",
      description: "Request to share a document",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email"},
        role: %Schema{type: :string, description: "Role", enum: ["suggestor", "viewer"]},
        state_id: %Schema{type: :string, description: "Document State"}
      },
      required: [:email, :role, :state_id],
      example: %{
        "email" => "example@example.com",
        "role" => "suggestor",
        "state_id" => "a102cdb1-e5f4-4c28-98ec-9a10a94b9173"
      }
    })
  end
end
