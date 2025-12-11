defmodule WraftDocWeb.Schemas.Flow do
  @moduledoc """
  Schema for Flow request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

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

  defmodule Flow do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow",
      description: "Flows to be followed in an organisation",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the flow"},
        name: %Schema{type: :string, description: "Name of the flow"},
        controlled: %Schema{
          type: :boolean,
          description: "Specifying controlled or uncontrolled flows"
        },
        inserted_at: %Schema{
          type: :string,
          description: "When was the flow inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the flow last updated",
          format: "ISO-8601"
        }
      },
      required: [:controlled],
      example: %{
        id: "1232148nb3478",
        name: "Flow 1",
        controlled: true,
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ControlledFlow do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Controlled Flow",
      description: "Flows to be followed in an organisation",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the flow"},
        name: %Schema{type: :string, description: "Name of the flow"},
        controlled: %Schema{
          type: :boolean,
          description: "Specifying controlled or uncontrolled flows"
        },
        control_data: %Schema{type: :object, description: "Approval system data"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the flow inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the flow last updated",
          format: "ISO-8601"
        }
      },
      required: [:controlled, :control_data],
      example: %{
        id: "1232148nb3478",
        name: "Flow 1",
        controlled: true,
        control_data: %{
          pre_state: "review",
          post_state: "publish",
          approver: "user_id"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule UpdateFlow do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show flow details",
      description: "Show all details of a flow",
      type: :object,
      properties: %{
        flow: Flow,
        creator: WraftDocWeb.Schemas.User.User
      },
      example: %{
        flow: %{
          id: "1232148nb3478",
          name: "Flow 1",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        creator: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule ShowFlows do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All flows and its details",
      description: "All flows that have been created and their details",
      type: :array,
      items: UpdateFlow
    })
  end

  defmodule FlowAndStates do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show flow details and its states",
      description: "Show all details of a flow including all the states undet the flow",
      type: :object,
      properties: %{
        flow: Flow,
        creator: WraftDocWeb.Schemas.User.User,
        states: %Schema{type: :array, items: WraftDocWeb.Schemas.State.State}
      },
      example: %{
        flow: %{
          id: "1232148nb3478",
          name: "Flow 1",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        creator: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        states: [
          %{
            id: "1232148nb3478",
            state: "published",
            order: 1,
            approvers: [
              %{
                id: "af2cf1c6-f342-4042-8425-6346e9fd6c44",
                name: "Richard Hendricks",
                profile_pic: "www.minio.com/users/johndoe.jpg"
              }
            ]
          }
        ]
      }
    })
  end

  defmodule FlowAndStatesWithoutCreator do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show flow details and its states",
      description: "Show all details of a flow including all the states undet the flow",
      type: :object,
      properties: %{
        flow: Flow,
        states: %Schema{type: :array, items: WraftDocWeb.Schemas.State.State}
      },
      example: %{
        flow: %{
          id: "1232148nb3478",
          name: "Flow 1",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        states: [
          %{
            id: "1232148nb3478",
            state: "published",
            order: 1
          }
        ]
      }
    })
  end

  defmodule AlignStateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show flow details and its states",
      description: "Show all details of a flow including all the states undet the flow",
      type: :object,
      properties: %{
        states: %Schema{type: :array, items: WraftDocWeb.Schemas.State.State}
      },
      example: %{
        states: [
          %{
            id: "1232148nb3478",
            order: 1
          },
          %{
            id: "1232148nb3478",
            order: 2
          }
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
        flows: ShowFlows,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        flows: [
          %{
            flow: %{
              id: "1232148nb3478",
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end
end
