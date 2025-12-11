defmodule WraftDocWeb.Schemas.InstanceApprovalSystem do
  @moduledoc """
  OpenAPI schemas for Instance Approval System operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule StateSchema do
    @moduledoc """
    Schema for state information
    """
    OpenApiSpex.schema(%{
      title: "State",
      description: "States of content",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "State ID"},
        state: %Schema{type: :string, description: "State name"},
        order: %Schema{type: :integer, description: "State order"}
      },
      example: %{
        id: "0sdffsafdsaf21f1ds21",
        state: "Draft",
        order: 1
      }
    })
  end

  defmodule UserSchema do
    @moduledoc """
    Schema for user information
    """
    OpenApiSpex.schema(%{
      title: "User",
      description: "A user of the application",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "User ID"},
        name: %Schema{type: :string, description: "User name"},
        email: %Schema{type: :string, format: :email, description: "User email"},
        email_verify: %Schema{type: :boolean, description: "Email verification status"},
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the user inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the user last updated"
        }
      },
      example: %{
        id: "1232148nb3478",
        name: "John Doe",
        email: "email@xyz.com",
        email_verify: true,
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule InstanceSchema do
    @moduledoc """
    Schema for instance/content information
    """
    OpenApiSpex.schema(%{
      title: "Content",
      description: "A content, which is then used to generate the out files",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Content ID"},
        instance_id: %Schema{type: :string, description: "A unique ID generated for the content"},
        raw: %Schema{type: :string, description: "Raw data of the content"},
        serialized: %Schema{type: :object, description: "Serialized data of the content"},
        build: %Schema{type: :string, description: "URL of the build document"},
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the content inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the content last updated"
        }
      },
      example: %{
        id: "1232148nb3478",
        instance_id: "OFFL01",
        raw: "Content",
        serialized: %{title: "Title of the content", body: "Body of the content"},
        build: "/organisations/f5837766-573f-427f-a916-cf39a3518c7b/OFFL01/OFFLET-v1.pdf",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ApprovalSystemSchema do
    @moduledoc """
    Schema for approval system
    """
    OpenApiSpex.schema(%{
      title: "ApprovalSystem",
      description: "An approval system configuration",
      type: :object,
      properties: %{
        pre_state: StateSchema,
        post_state: StateSchema,
        approver: UserSchema,
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the approval_system inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the approval_system last updated"
        }
      },
      example: %{
        pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
        post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
        approver: %{id: "03asdfasfd00f0302as", name: "Approver"},
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule InstanceApprovalSystemItem do
    @moduledoc """
    Schema for instance approval system item
    """
    OpenApiSpex.schema(%{
      title: "Instance Approval System",
      description: "Approval system to follow by an instance",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "ID"},
        flag: %Schema{type: :boolean, description: "Flag to specify approved or not"},
        order: %Schema{
          type: :integer,
          description: "Order of the pre state of the approval system"
        },
        instance: InstanceSchema,
        approval_system: ApprovalSystemSchema
      },
      example: %{
        id: "26ds-s4fd5-sd1f541-sdf415sd",
        flag: false,
        order: 1,
        instance: %{
          id: "1232148nb3478",
          instance_id: "OFFL01",
          raw: "Content",
          serialized: %{title: "Title of the content", body: "Body of the content"},
          build: "/organisations/f5837766-573f-427f-a916-cf39a3518c7b/OFFL01/OFFLET-v1.pdf",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        approval_system: %{
          pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
          post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
          approver: %{id: "03asdfasfd00f0302as", name: "Approver"},
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule InstanceApprovalSystemIndex do
    @moduledoc """
    Schema for paginated instance approval system list
    """
    OpenApiSpex.schema(%{
      title: "Instance Approval System Index",
      description: "Paginated list of instance approval systems",
      type: :object,
      properties: %{
        instance_approval_systems: %Schema{
          type: :array,
          description: "List of instance approval systems",
          items: InstanceApprovalSystemItem
        },
        page_number: %Schema{type: :integer, description: "Current page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of entries"}
      },
      example: %{
        instance_approval_systems: [
          %{
            id: "26ds-s4fd5-sd1f541-sdf415sd",
            flag: false,
            order: 1
          }
        ],
        page_number: 1,
        total_pages: 1,
        total_entries: 1
      }
    })
  end
end
