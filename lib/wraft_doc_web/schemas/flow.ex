defmodule WraftDocWeb.Schemas.Flow do
  @moduledoc """
  Schema for Flow request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.{ApprovalSystem, State, User}

  defmodule FlowRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow Request",
      description: "Create flow request.",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Flow's name"},
        controlled: %Schema{
          type: :boolean,
          description: "Specifying controlled or uncontrolled flows"
        }
      },
      required: [:name, :controlled],
      example: %{
        name: "Flow 1",
        controlled: false
      }
    })
  end

  defmodule ControlledFlowRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      description: "Create controlled flow request",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Flow name"},
        controlled: %Schema{
          type: :boolean,
          description: "Specifying controlled or uncontrolled flows"
        },
        control_data: %Schema{type: :object, description: "Approval system data"}
      },
      required: [:name, :controlled, :control_data],
      example: %{
        name: "Flow 2",
        controlled: true,
        control_data: %{
          pre_state: "review",
          post_state: "publish",
          approver: "user_id"
        }
      }
    })
  end

  defmodule FlowBase do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow Base",
      description: "Basic flow details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the flow"},
        name: %Schema{type: :string, description: "Name of the flow"},
        controlled: %Schema{
          type: :boolean,
          description: "Specifying controlled or uncontrolled flows"
        },
        control_data: %Schema{type: :object, description: "Approval system data"},
        inserted_at: %Schema{type: :string, format: "ISO-8601"},
        updated_at: %Schema{type: :string, format: "ISO-8601"}
      },
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        name: "Flow 1",
        controlled: true,
        control_data: %{
          pre_state: "review",
          post_state: "publish",
          approver: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule FlowWithCreator do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow with Creator",
      description: "Flow details with creator info",
      type: :object,
      properties: %{
        flow: FlowBase,
        creator: User.User
      }
    })
  end

  defmodule FlowFull do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow Full Details",
      description: "Flow details with states and approval systems",
      type: :object,
      properties: %{
        flow: FlowBase,
        creator: User.User,
        states: %Schema{type: :array, items: State.State},
        approval_systems: %Schema{type: :array, items: ApprovalSystem.ApprovalSystem}
      }
    })
  end

  defmodule FlowAndStatesWithoutCreator do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow and States",
      description: "Flow details with states",
      type: :object,
      properties: %{
        flow: FlowBase,
        states: %Schema{type: :array, items: State.State}
      }
    })
  end

  defmodule AlignStateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Align State Request",
      description: "Request to align states",
      type: :object,
      properties: %{
        states: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{id: %Schema{type: :string}, order: %Schema{type: :integer}}
          }
        }
      },
      example: %{
        states: [
          %{id: "3fa85f64-5717-4562-b3fc-2c963f66afa6", order: 1},
          %{id: "3fa85f64-5717-4562-b3fc-2c963f66afa7", order: 2}
        ]
      }
    })
  end

  defmodule FlowIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow Index",
      description: "List of flows",
      type: :object,
      properties: %{
        flows: %Schema{type: :array, items: FlowWithCreator},
        page_number: %Schema{type: :integer},
        total_pages: %Schema{type: :integer},
        total_entries: %Schema{type: :integer}
      }
    })
  end
end
