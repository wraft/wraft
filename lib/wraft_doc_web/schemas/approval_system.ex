defmodule WraftDocWeb.Schemas.ApprovalSystem do
  @moduledoc """
  Schema for ApprovalSystem request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

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
      }
    })
  end

  defmodule Approver do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Approver",
      description: "Approver of the content",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Approvers id"},
        name: %Schema{type: :string, description: "Name of the approver"}
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
        pre_state: State,
        post_state: State,
        approver: Approver,
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
        instance: %{id: "0sdf21d12sdfdfdf"},
        pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
        post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
        approver: %{id: "03asdfasfd00f0302as", name: "Approver"},
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
        post_stae: State,
        approved: %Schema{type: :boolean, description: "The system has been approved"}
      },
      example: %{
        instance: %{
          id: "3adfafd12a1fsd561a1df",
          stete_id: "2a2ds3fads3f2sd66s2adf6",
          state: "Publish"
        },
        pre_state: %{id: "sdfasdf32ds6f2as6f262saf62", state: "Draft"},
        post_state: %{id: "dsadsffasdfsfasdff2asdf32f", state: "Publish"},
        approved: true
      }
    })
  end
end
