defmodule WraftDocWeb.Schemas.State do
  @moduledoc """
  Schema for State request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule StateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "State Request",
      description: "Create state request.",
      type: :object,
      properties: %{
        state: %Schema{type: :string, description: "State name"},
        order: %Schema{type: :integer, description: "State's order"},
        type: %Schema{type: :string, description: "State's type"},
        approvers: %Schema{
          type: :array,
          description: "State's approvers",
          items: %Schema{type: :string}
        }
      },
      required: [:state, :order, :approvers],
      example: %{
        state: "Published",
        order: 1,
        type: "reviewer",
        approvers: [
          "b840c04c-25a2-4426-895a-acd2685153e4",
          "b190bece-160c-44cc-91e9-79367ed2ccf6"
        ]
      }
    })
  end

  defmodule UpdateStateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Update State Request",
      description: "Update state request.",
      type: :object,
      properties: %{
        state: %Schema{type: :string, description: "State name"},
        order: %Schema{type: :integer, description: "State's order"},
        type: %Schema{type: :string, description: "State's type"},
        approvers: %Schema{type: :object, description: "State's approvers"}
      },
      example: %{
        state: "Published",
        order: 3,
        type: "reviewer",
        approvers: %{
          add: [
            "b840c04c-25a2-4426-895a-acd2685153e4",
            "b190bece-160c-44cc-91e9-79367ed2ccf6"
          ],
          remove: [
            "b840c04c-25a2-4426-895a-acd2685153e4",
            "b190bece-160c-44cc-91e9-79367ed2ccf6"
          ]
        }
      }
    })
  end

  defmodule State do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "State",
      description: "State assigened to contents",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the state"},
        state: %Schema{type: :string, description: "A state of content"},
        order: %Schema{type: :integer, description: "Order of the state"},
        type: %Schema{type: :string, description: "Type of the state"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the state inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the state last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "1232148nb3478",
        state: "published",
        order: 1,
        type: "reviewer",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule ShowState do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show flow details",
      description: "Show all details of a flow",
      type: :object,
      properties: %{
        state: State,
        creator: WraftDocWeb.Schemas.User.User,
        flow: WraftDocWeb.Schemas.Flow.Flow
      },
      example: %{
        state: %{
          id: "1232148nb3478",
          state: "published",
          order: 1,
          type: "reviewer",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        approvers: [
          "b840c04c-25a2-4426-895a-acd2685153e4",
          "b190bece-160c-44cc-91e9-79367ed2ccf6"
        ],
        creator: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        flow: %{
          id: "jnb234881adsad",
          name: "Flow 1",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule ShowStates do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All states and its details",
      description: "All states that have been created and their details",
      type: :array,
      items: ShowState
    })
  end

  defmodule FlowIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Flow Index",
      type: :object,
      properties: %{
        states: ShowStates
      },
      example: %{
        states: [
          %{
            state: %{
              id: "1232148nb3478",
              state: "published",
              order: 1,
              type: "reviewer",
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
            flow: %{
              id: "jnb234881adsad",
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          }
        ]
      }
    })
  end

  defmodule StateUserDocumentLevelRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "State User Document Level Request",
      type: :object,
      properties: %{
        content_id: %Schema{type: :string, description: "Document id"}
      },
      required: [:content_id],
      example: %{
        content_id: "f0b206b0-94e5-4bcb-a87b-1656166d9ebb"
      }
    })
  end

  defmodule StateUserDocumentLevelResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "State User Document Level Response",
      type: :object,
      properties: %{
        users: %Schema{type: :array, items: WraftDocWeb.Schemas.User.User}
      },
      example: %{
        users: [
          %{
            id: "1232148nb3478",
            name: "John Doe",
            email: "email@xyz.com",
            email_verify: true,
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ]
      }
    })
  end
end
