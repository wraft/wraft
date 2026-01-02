defmodule WraftDocWeb.Schemas.ApprovalSystem do
  @moduledoc """
  Schema for ApprovalSystem request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.{Flow, User}

  defmodule ApprovalSystemRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ApprovalSystem Request",
      description: "Create approval_system request.",
      type: :object,
      required: [:flow_id, :pre_state_id, :post_state_id, :approver_id],
      properties: %{
        flow_id: %Schema{type: :string, description: "The id of flow"},
        pre_state_id: %Schema{type: :string, description: "The id of state before"},
        post_state_id: %Schema{type: :string, description: "The id of state after"},
        approver_id: %Schema{type: :string, description: "The id of approver"}
      },
      example: %{
        flow_id: "0sdf21d12sdfdfdf",
        pre_state_id: "0sdffsafdsaf21f1ds21",
        post_state_id: "33sdf0a3sf0d300sad",
        approver_id: "03asdfasfd00f032as"
      }
    })
  end

  defmodule State do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "State",
      description: "States of content",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "States id"},
        state: %Schema{type: :string, description: "State of the content"}
      },
      example: %{
        id: "0fbe4703-d7eb-4a75-b850-e0c4457d4e32",
        state: "draft"
      }
    })
  end

  defmodule ApprovedInstance do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Approved instance",
      description: "Content approved by approver",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Instance id"},
        state_id: %Schema{type: :string, description: "State id"},
        state: %Schema{type: :string, description: "Current State"}
      },
      example: %{
        id: "0fbe4703-d7eb-4a75-b850-e0c4457d4e32",
        state_id: "dabc3e2d-10a8-4f8a-a360-8b47f3934968",
        state: "published"
      }
    })
  end

  defmodule ApprovalSystemObject do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Approval System Object",
      description: "Approval System basic details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Approval System ID"},
        name: %Schema{type: :string, description: "Approval System Name"},
        pre_state_id: %Schema{type: :string, description: "Pre-state ID"},
        post_state_id: %Schema{type: :string, description: "Post-state ID"},
        flow_id: %Schema{type: :string, description: "Flow ID"},
        approver_id: %Schema{type: :string, description: "Approver ID"}
      },
      example: %{
        id: "0sdf21d12sdfdfdf",
        name: "Manager Approval",
        pre_state_id: "0sdffsafdsaf21f1ds21",
        post_state_id: "33sdf0a3sf0d300sad",
        flow_id: "0sdf21d12sdfdfdf",
        approver_id: "03asdfasfd00f032as"
      }
    })
  end

  defmodule ApprovalSystem do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ApprovalSystem",
      description: "A ApprovalSystem",
      type: :object,
      properties: %{
        approval_system: ApprovalSystemObject,
        pre_state: State,
        post_state: State,
        flow: Flow.Flow,
        approver: User.User,
        inserted_at: %Schema{
          type: :string,
          description: "When was the approval_system inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the approval_system last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        approval_system: %{
          id: "0sdf21d12sdfdfdf",
          name: "Manager Approval",
          pre_state_id: "0sdffsafdsaf21f1ds21",
          post_state_id: "33sdf0a3sf0d300sad",
          flow_id: "0sdf21d12sdfdfdf",
          approver_id: "03asdfasfd00f032as"
        },
        pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
        post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
        flow: %{
          id: "1232148nb3478",
          name: "Flow 1",
          controlled: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        approver: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule Approved do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Approve content",
      description: "To approve a content",
      type: :object,
      properties: %{
        instance: ApprovedInstance,
        pre_state: State,
        post_state: State,
        approved: %Schema{type: :boolean, description: "The system has been approved"}
      },
      example: %{
        instance: %{
          id: "3adfafd12a1fsd561a1df",
          state_id: "2a2ds3fads3f2sd66s2adf6",
          state: "Publish"
        },
        pre_state: %{id: "sdfasdf32ds6f2as6f262saf62", state: "Draft"},
        post_state: %{id: "dsadsffasdfsfasdff2asdf32f", state: "Publish"},
        approved: true
      }
    })
  end

  defmodule ApprovalSystemResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Approval Systems Response",
      description: "List of approval systems",
      type: :object,
      properties: %{
        approval_systems: %Schema{type: :array, items: ApprovalSystem},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of entries"},
        page_size: %Schema{type: :integer, description: "Page size"}
      },
      example: %{
        approval_systems: [
          %{
            approval_system: %{
              id: "0sdf21d12sdfdfdf",
              name: "Manager Approval",
              pre_state_id: "0sdffsafdsaf21f1ds21",
              post_state_id: "33sdf0a3sf0d300sad",
              flow_id: "0sdf21d12sdfdfdf",
              approver_id: "03asdfasfd00f032as"
            },
            pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
            post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
            flow: %{
              id: "1232148nb3478",
              name: "Flow 1",
              controlled: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            approver: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ],
        page_number: 1,
        total_pages: 5,
        total_entries: 50,
        page_size: 10
      }
    })
  end
end
