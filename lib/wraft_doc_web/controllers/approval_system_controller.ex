defmodule WraftDocWeb.Api.V1.ApprovalSystemController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "approval_system:manage",
    show: "approval_system:show",
    update: "approval_system:manage",
    delete: "approval_system:delete",
    index: "approval_system:show"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.ApprovalSystem

  def swagger_definitions do
    %{
      ApprovalSystemRequest:
        swagger_schema do
          title("ApprovalSystem Request")
          description("Create approval_system request.")

          properties do
            flow_id(:string, "The id of flow", required: true)
            pre_state_id(:string, "The id of state before", required: true)
            post_state_id(:string, "The id of state after", required: true)
            approver_id(:string, "The id of approver", required: true)
          end

          example(%{
            flow_id: "0sdf21d12sdfdfdf",
            pre_state_id: "0sdffsafdsaf21f1ds21",
            post_state_id: "33sdf0a3sf0d300sad",
            approver_id: "03asdfasfd00f032as"
          })
        end,
      State:
        swagger_schema do
          title("State")
          description("States of content")

          properties do
            id(:string, "States id")
            state(:string, "State of the content")
          end
        end,
      Approver:
        swagger_schema do
          title("Approver")
          description("Approver of the content")

          properties do
            id(:string, "Approvers id")
            name(:string, "Name of the approver")
          end
        end,
      ApprovedInstance:
        swagger_schema do
          title("Approved instance")
          description("Content approved by approver")

          properties do
            id(:string, "Instance id")
            state_id(:string, "State id")
            state(:string, "Current State")
          end
        end,
      ApprovalSystem:
        swagger_schema do
          title("ApprovalSystem")
          description("A ApprovalSystem")

          properties do
            pre_state(Schema.ref(:State))
            post_state(Schema.ref(:State))
            approver(Schema.ref(:Approver))

            inserted_at(:string, "When was the approval_system inserted", format: "ISO-8601")
            updated_at(:string, "When was the approval_system last updated", format: "ISO-8601")
          end

          example(%{
            instance: %{id: "0sdf21d12sdfdfdf"},
            pre_state: %{id: "0sdffsafdsaf21f1ds21", state: "Draft"},
            post_state: %{id: "33sdf0a3sf0d300sad", state: "Publish"},
            approver: %{id: "03asdfasfd00f0302as", name: "Approver"},
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      Approved:
        swagger_schema do
          title("Approve content")
          description("To approve a content")

          properties do
            instance(Schema.ref(:ApprovedInstance))
            pre_state(Schema.ref(:State))
            post_stae(Schema.ref(:State))
            approved(:boolean, "The system has been approved")
          end

          example(%{
            instance: %{
              id: "3adfafd12a1fsd561a1df",
              stete_id: "2a2ds3fads3f2sd66s2adf6",
              state: "Publish"
            },
            pre_state: %{id: "sdfasdf32ds6f2as6f262saf62", state: "Draft"},
            post_state: %{id: "dsadsffasdfsfasdff2asdf32f", state: "Publish"},
            approved: true
          })
        end
    }
  end

  swagger_path :create do
    post("/approval_systems")
    summary("Create approval_system")
    description("Create approval_system API")

    parameters do
      approval_system(:body, Schema.ref(:ApprovalSystemRequest), "ApprovalSystem to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:ApprovalSystem))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <-
           Enterprise.create_approval_system(current_user, params) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  swagger_path :show do
    get("/approval_systems/{id}")
    summary("Show a approval_system")
    description("API to show details of a approval_system")

    parameters do
      id(:path, :string, "approval_system id", required: true)
    end

    response(200, "Ok", Schema.ref(:ApprovalSystem))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <- Enterprise.show_approval_system(id, current_user) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  swagger_path :update do
    put("/approval_systems/{id}")
    summary("Update a approval_system")
    description("API to update a approval_system")

    parameters do
      id(:path, :string, "approval_system id", required: true)

      approval_system(:body, Schema.ref(:ApprovalSystemRequest), "ApprovalSystem to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:ApprovalSystem))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <-
           Enterprise.get_approval_system(id, current_user),
         %ApprovalSystem{} = approval_system <-
           Enterprise.update_approval_system(current_user, approval_system, params) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/approval_systems/{id}")
    summary("Delete a approval_system")
    description("API to delete a approval_system")

    parameters do
      id(:path, :string, "approval_system id", required: true)
    end

    response(200, "Ok", Schema.ref(:ApprovalSystem))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <-
           Enterprise.get_approval_system(id, current_user),
         %ApprovalSystem{} = approval_system <- Enterprise.delete_approval_system(approval_system) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  swagger_path :index do
    get("/approval_systems")
    summary("Approval systems")
    description("Api to list approval systems")

    parameters do
      page(:query, :string, "Page")
    end

    response(200, "Ok", Schema.ref(:Approved))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: approval_systems,
           page_number: page_number,
           page_size: page_size,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.list_approval_systems(current_user, params) do
      render(conn, "index.json",
        approval_systems: approval_systems,
        page_number: page_number,
        page_size: page_size,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
