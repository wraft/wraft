defmodule WraftDocWeb.Api.V1.ApprovalSystemController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.{
    Enterprise,
    Enterprise.ApprovalSystem,
    Document,
    Account,
    Account.User,
    Document.Instance,
    Enterprise.Flow.State
  }

  def swagger_definitions do
    %{
      ApprovalSystemRequest:
        swagger_schema do
          title("ApprovalSystem Request")
          description("Create approval_system request.")

          properties do
            instance_id(:string, "The id of instance to approve", required: true)
            pre_state_id(:string, "The Prirmary state id", required: true)
            post_state_id(:string, "The state to change by approval", required: true)
            approver_id(:string, "The id of approver", required: true)
          end

          example(%{
            instance_id: "0sdf21d12sdfdfdf",
            pre_state_id: "0sdffsafdsaf21f1ds21",
            post_state_id: "33sdf0a3sf0d300sad",
            approver_id: "03asdfasfd00f032as"
          })
        end,
      ApprovalSystem:
        swagger_schema do
          title("ApprovalSystem")
          description("A ApprovalSystem")

          properties do
            instance_id(:string, "The id of instance to approve", required: true)
            pre_state_id(:string, "The Prirmary state id", required: true)
            post_state_id(:string, "The state to change by approval", required: true)
            approver_id(:string, "The id of approver", required: true)

            inserted_at(:string, "When was the approval_system inserted", format: "ISO-8601")
            updated_at(:string, "When was the approval_system last updated", format: "ISO-8601")
          end

          example(%{
            instance: "0sdf21d12sdfdfdf",
            pre_state_id: "0sdffsafdsaf21f1ds21",
            post_state_id: "33sdf0a3sf0d300sad",
            approver_id: "03asdfasfd00f0302as",
            user: "03sdfadsfa30sdf",
            organisation: "020sdf20s2a0f2",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
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
      conn |> render("approval_system.json", approval_system: approval_system)
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
  def show(conn, %{"id" => uuid}) do
    with %ApprovalSystem{} = approval_system <- Enterprise.get_approval_system(uuid) do
      conn
      |> render("approval_system.json", approval_system: approval_system)
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
  def update(conn, %{"id" => uuid} = params) do
    with %ApprovalSystem{} = approval_system <- Enterprise.get_approval_system(uuid),
         %ApprovalSystem{} = approval_system <-
           Enterprise.update_approval_system(approval_system, params) do
      conn
      |> render("approval_system.json", approval_system: approval_system)
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
  def delete(conn, %{"id" => uuid}) do
    with %ApprovalSystem{} = approval_system <- Enterprise.get_approval_system(uuid),
         {:ok, %ApprovalSystem{}} <- Enterprise.delete_approval_system(approval_system) do
      conn
      |> render("approval_system.json", approval_system: approval_system)
    end
  end

  swagger_path :approve do
    post("/approval_systems/approve")
    summary("Approve a state")
    description("Api to approve a state")

    parameters do
      id(:query, :string, "approval_system id", required: true)
    end

    response(200, "Ok", Schema.ref(:ApprovalSystem))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  def approve(conn, %{"id" => uuid}) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <- Enterprise.get_approval_system(uuid),
         %ApprovalSystem{instance: instance} = approval_system <-
           Enterprise.approve_content(current_user, approval_system),
         %Instance{} = instance <- Document.get_instance(instance.uuid) do
      conn
      |> render("approve.json", approval_system: approval_system, instance: instance)
    end
  end
end
