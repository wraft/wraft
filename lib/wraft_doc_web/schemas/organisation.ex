defmodule WraftDocWeb.Schemas.Organisation do
  @moduledoc """
  Schema for Organisation request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  # alias WraftDocWeb.Schemas.User

  defmodule OrganisationRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation Request",
      description: "An organisation to be register for enterprice operation",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Organisation name"},
        legal_name: %Schema{type: :string, description: "Legal name of organisation"},
        address: %Schema{type: :string, description: "Address of organisation"},
        gstin: %Schema{type: :string, description: "Goods and service tax invoice numger"},
        email: %Schema{type: :string, description: "Official email"},
        phone: %Schema{type: :string, description: "Offical Phone number"}
      },
      required: [:name, :legal_name],
      example: %{
        name: "ABC enterprices",
        legal_name: "ABC enterprices LLC",
        address: "#24, XV Building, TS DEB Layout ",
        gstin: "32AA65FF56545353",
        email: "abcent@gmail.com",
        phone: "865623232"
      }
    })
  end

  defmodule Organisation do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation",
      description: "An Organisation",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The id of an organisation"},
        name: %Schema{type: :string, description: "Name of the organisation"},
        legal_name: %Schema{type: :string, description: "Legal Name of the organisation"},
        address: %Schema{type: :string, description: "Address of the organisation"},
        name_of_ceo: %Schema{type: :string, description: "Organisation CEO's Name"},
        name_of_cto: %Schema{type: :string, description: "Organisation CTO's Name"},
        gstin: %Schema{type: :string, description: "GSTIN of organisation"},
        corporate_id: %Schema{type: :string, description: "Corporate id of organisation"},
        members_count: %Schema{type: :integer, description: "Number of members"},
        phone: %Schema{type: :string, description: "Phone number of organisation"},
        email: %Schema{type: :string, description: "Email of organisation"},
        logo: %Schema{type: :string, description: "Logo of organisation"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When was the user last updated"
        }
      },
      required: [:id, :name, :legal_name],
      example: %{
        id: "mnbjhb23488n23e",
        name: "ABC enterprices",
        legal_name: "ABC enterprices LLC",
        address: "#24, XV Building, TS DEB Layout ",
        name_of_ceo: "John Doe",
        name_of_cto: "Foo Doo",
        gstin: "32AA65FF56545353",
        corporate_id: "BNIJSN1234NGT",
        members_count: 6,
        email: "abcent@gmail.com",
        logo: "/logo.jpg",
        phone: "865623232",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule InvitedResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Invite user response",
      description: "Invite user response",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      required: [:info],
      example: %{info: "Invited successfully.!"}
    })
  end

  defmodule RevokedResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Revoke invite user response",
      description: "Revoke Invite user response",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      required: [:info],
      example: %{info: "Invited successfully.!"}
    })
  end

  defmodule InviteTokenStatusResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Invite Token Status",
      description: "Invite Token Status",
      type: :object,
      properties: %{
        isNewUser: %Schema{type: :boolean, description: "Invite token status"},
        email: %Schema{type: :string, description: "Email of the user"}
      },
      required: [:isNewUser, :email],
      example: %{
        isNewUser: true,
        email: "abcent@gmail.com"
      }
    })
  end

  defmodule ListOfOrganisations do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisations array",
      description: "List of existing Organisations",
      type: :array,
      items: Organisation
    })
  end

  defmodule Index do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation index",
      type: :object,
      properties: %{
        organisations: ListOfOrganisations,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        organisations: [
          %{
            id: "mnbjhb23488n23e",
            name: "ABC enterprices",
            legal_name: "ABC enterprices LLC",
            address: "#24, XV Building, TS DEB Layout ",
            name_of_ceo: "John Doe",
            name_of_cto: "Foo Doo",
            gstin: "32AA65FF56545353",
            corporate_id: "BNIJSN1234NGT",
            email: "abcent@gmail.com",
            logo: "/logo.jpg",
            phone: "865623232",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ],
        page_number: 1,
        total_pages: 1,
        total_entries: 1
      }
    })
  end

  defmodule Members do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Members array",
      description: "List of Users/members of an organisation.",
      type: :array,
      items: WraftDocWeb.Schemas.User.ShowCurrentUser
    })
  end

  defmodule MembersIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Members index",
      type: :object,
      properties: %{
        members: Members,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      }
    })
  end

  defmodule RemoveUser do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Remove User",
      description: "Removes the user from the organisation",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      required: [:info],
      example: %{info: "User removed from the organisation.!"}
    })
  end

  defmodule DeleteOrganisationRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Delete Confirmation Token",
      description: "Request body to delete an organisation",
      type: :object,
      properties: %{
        token: %Schema{type: :string, description: "Token"}
      },
      required: [:token],
      example: %{
        token: "123456"
      }
    })
  end

  defmodule PermissionsResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Current User Permissions",
      description: "Current user permissions of current organisation",
      type: :object,
      example: %{
        permissions: %{
          asset: [
            "show",
            "manage",
            "delete"
          ],
          block: [
            "show",
            "manage",
            "delete"
          ]
        }
      }
    })
  end

  defmodule DeletionRequestResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Delete Confirmation Code",
      description: "Delete Confirmation Code Response",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Response Info"}
      },
      example: %{
        info: "Delete token email sent!"
      }
    })
  end

  defmodule VerifyOrganisationInviteTokenResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Verify Organisation invite token",
      description:
        "Verifies Organisation invite token and returns organisation details and user's details",
      type: :object,
      properties: %{
        organisation: Organisation
      }
    })
  end

  defmodule InviteRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Invite user",
      description: "Request body to invite a user to an organisation",
      type: :object,
      properties: %{
        email: %Schema{type: :string, description: "Email of the user"},
        role_ids: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "IDs of roles for the user"
        }
      },
      required: [:email, :role_ids],
      example: %{
        email: "abcent@gmail.com",
        role_ids: ["756f1fa1-9657-4166-b372-21e8135aeaf1"]
      }
    })
  end

  defmodule InvitedUser do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "InvitedUser",
      description: "An invited user",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "User ID"},
        email: %Schema{type: :string, description: "Email address"},
        status: %Schema{type: :string, description: "Invitation status"}
      },
      required: [:id, :email, :status]
    })
  end

  defmodule InvitedUsersResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "InvitedUsersResponse",
      description: "A list of invited users",
      type: :array,
      items: InvitedUser
    })
  end
end
