defmodule WraftDocWeb.Api.V1.FlowController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "flow:manage",
    index: "flow:show",
    show: "flow:show",
    update: "flow:manage",
    align_states: "flow:manage",
    delete: "flow:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow

  def swagger_definitions do
    %{
      FlowRequest:
        swagger_schema do
          title("Flow Request")
          description("Create flow request.")

          properties do
            name(:string, "Flow's name", required: true)
            controlled(:boolean, "Specifying controlled or uncontrolled flows", required: true)
          end

          example(%{
            name: "Flow 1",
            controlled: false
          })
        end,
      ControlledFlowRequest:
        swagger_schema do
          description("Create controlled flow request")

          properties do
            name(:string, "Flow name", required: true)
            controlled(:boolean, "Specifying controlled or uncontrolled flows", required: true)
            control_data(:map, "Approval system data", required: true)
          end

          example(%{
            name: "Flow 2",
            controlled: true,
            control_data: %{
              pre_state: "review",
              post_state: "publish",
              approver: "user_id"
            }
          })
        end,
      Flow:
        swagger_schema do
          title("Flow")
          description("Flows to be followed in an organisation")

          properties do
            id(:string, "ID of the flow")
            name(:string, "Name of the flow")
            controlled(:boolean, "Specifying controlled or uncontrolled flows", required: true)
            inserted_at(:string, "When was the flow inserted", format: "ISO-8601")
            updated_at(:string, "When was the flow last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Flow 1",
            controlled: true,
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ControlledFlow:
        swagger_schema do
          title("Controlled Flow")
          description("Flows to be followed in an organisation")

          properties do
            id(:string, "ID of the flow")
            name(:string, "Name of the flow")
            controlled(:boolean, "Specifying controlled or uncontrolled flows", required: true)
            control_data(:map, "Approval system data", required: true)

            inserted_at(:string, "When was the flow inserted", format: "ISO-8601")
            updated_at(:string, "When was the flow last updated", format: "ISO-8601")
          end

          example(%{
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
          })
        end,
      User:
        swagger_schema do
          title("User")
          description("user details")

          properties do
            name(:string, "Users name")
            email(:string, "Users email")
          end

          example(%{
            name: "user name",
            email: "user@gmai.com"
          })
        end,
      UpdateFlow:
        swagger_schema do
          title("Show flow details")
          description("Show all details of a flow")

          properties do
            flow(Schema.ref(:Flow))
            creator(Schema.ref(:User))
          end

          example(%{
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
          })
        end,
      ShowFlows:
        swagger_schema do
          title("All flows and its details")
          description("All flows that have been created and their details")
          type(:array)
          items(Schema.ref(:UpdateFlow))
        end,
      FlowAndStates:
        swagger_schema do
          title("Show flow details and its states")
          description("Show all details of a flow including all the states undet the flow")

          properties do
            flow(Schema.ref(:Flow))
            creator(Schema.ref(:User))
            states(Schema.ref(:State))
          end

          example(%{
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
                order: 1
              }
            ]
          })
        end,
      FlowAndStatesWithoutCreator:
        swagger_schema do
          title("Show flow details and its states")
          description("Show all details of a flow including all the states undet the flow")

          properties do
            flow(Schema.ref(:Flow))
            states(Schema.ref(:State))
          end

          example(%{
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
          })
        end,
      AlignStateRequest:
        swagger_schema do
          title("Show flow details and its states")
          description("Show all details of a flow including all the states undet the flow")

          properties do
            states(Schema.ref(:State))
          end

          example(%{
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
          })
        end,
      FlowIndex:
        swagger_schema do
          properties do
            flows(Schema.ref(:ShowFlows))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
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
          })
        end
    }
  end

  @doc """
  Create a flow.
  """
  swagger_path :create do
    post("/flows")
    summary("Create a flow")
    description("Create flow API")

    parameters do
      flow(:body, Schema.ref(:ControlledFlowRequest), "Flow to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:ControlledFlow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <-
           Enterprise.create_flow(current_user, params) do
      render(conn, "flow.json", flow: flow)
    end
  end

  @doc """
  Flow index.
  """
  swagger_path :index do
    get("/flows")
    summary("Flow index")
    description("Index of flows in current user's organisation")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:FlowIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: flows,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.flow_index(current_user, params) do
      render(conn, "index.json",
        flows: flows,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show Flow.
  """
  swagger_path :show do
    get("/flows/{id}")
    summary("Show a flow")
    description("Show a flow and its details including states under it")

    parameters do
      id(:path, :string, "flow id", required: true)
    end

    response(200, "Ok", Schema.ref(:FlowAndStates))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => flow_id}) do
    current_user = conn.assigns.current_user

    with %Flow{} = flow <- Enterprise.show_flow(flow_id, current_user) do
      render(conn, "show.json", flow: flow)
    end
  end

  @doc """
  Flow update.
  """
  swagger_path :update do
    put("/flows/{id}")
    summary("Flow update")
    description("API to update a flow")

    parameters do
      id(:path, :string, "flow id", required: true)
      flow(:body, Schema.ref(:FlowRequest), "Flow to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:UpdateFlow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(id, current_user),
         %Flow{} = flow <- Enterprise.update_flow(flow, params) do
      render(conn, "update.json", flow: flow)
    end
  end

  swagger_path :align_states do
    put("/flows/{id}/align-states")
    summary("Update states")
    description("Api to update order of states of a flow")

    parameters do
      id(:path, :string, "Flow id", required: true)

      flow(:body, Schema.ref(:AlignStateRequest), "Flow and states to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:FlowAndStates))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  def align_states(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Flow{} = flow <- Enterprise.show_flow(id, current_user),
         %Flow{} = flow <- Enterprise.align_states(flow, params) do
      render(conn, "show.json", %{flow: flow})
    end
  end

  @doc """
  Flow delete.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/flows/{id}")
    summary("Flow delete")
    description("API to delete a flow")

    parameters do
      id(:path, :string, "flow id", required: true)
    end

    response(200, "Ok", Schema.ref(:Flow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(id, current_user),
         {:ok, %Flow{}} <- Enterprise.delete_flow(flow) do
      render(conn, "flow.json", flow: flow)
    end
  end
end
