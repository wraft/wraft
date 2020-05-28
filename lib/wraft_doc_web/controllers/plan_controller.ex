defmodule WraftDocWeb.Api.V1.PlanController do
  use WraftDocWeb, :controller
  plug(WraftDocWeb.Plug.AddActionLog)
  import Ecto.Query, warn: false
  alias WraftDoc.{Enterprise, Enterprise.Plan}
  action_fallback(WraftDocWeb.FallbackController)

  use PhoenixSwagger

  def swagger_definitions do
    %{
      Plan:
        swagger_schema do
          title("Plan")
          description("A plan")

          properties do
            id(:string, "Plan id")
            name(:string, "Plan name")
            description(:string, "Plan description")
            yearly_amount(:integer, "Yearly amount of the plan")
            monthly_amount(:integer, "Monthly amount of the plan")
            inserted_at(:string, "When was the plan inserted", format: "ISO-8601")
            updated_at(:string, "When was the plan last updated", format: "ISO-8601")
          end

          example(%{
            id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
            name: "Basic",
            description: "A basic plan",
            yearly_amount: 10,
            monthly_amount: 6,
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      PlanRequest:
        swagger_schema do
          title("Plan request")
          description("Plan create/update request")

          properties do
            name(:string, "Plan name", required: true)
            description(:string, "Plan description", required: true)
            yearly_amount(:integer, "Yearly amount of the plan")
            monthly_amount(:integer, "Monthly amount of the plan")
          end

          example(%{
            name: "Basic",
            description: "A basic plan",
            yearly_amount: 10,
            monthly_amount: 6
          })
        end,
      Plans:
        swagger_schema do
          title("All plans")
          description("All plans that have been created")
          type(:array)
          items(Schema.ref(:Plan))
        end
    }
  end

  swagger_path :create do
    post("/plans")
    summary("Create a plan")
    description("Create a plan")
    operation_id("create_plan")

    parameters do
      plan(:body, Schema.ref(:PlanRequest), "Plan to be created", required: true)
    end

    response(200, "Updated", Schema.ref(:Plan))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    with {:ok, %Plan{} = plan} <- Enterprise.create_plan(params) do
      conn |> render("plan.json", plan: plan)
    end
  end

  swagger_path :index do
    post("/plans")
    summary("Plan index")
    description("List all plans created so far")
    operation_id("plan_index")

    response(200, "OK", Schema.ref(:Plans))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    plans = Enterprise.plan_index()
    conn |> render("plans.json", plans: plans)
  end

  swagger_path :show do
    post("/plans/{id}")
    summary("Show Plan")
    description("Show a plan")
    operation_id("show_plan")

    response(200, "OK", Schema.ref(:Plan))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => p_uuid}) do
    with %Plan{} = plan <- Enterprise.get_plan(p_uuid) do
      conn |> render("plan.json", plan: plan)
    end
  end

  swagger_path :update do
    put("/plans/{id}")
    summary("Update a plan")
    description("Update a plan")
    operation_id("update_plan")

    parameters do
      id(:path, :string, "ID of the plan to be updated")
      plan(:body, Schema.ref(:PlanRequest), "Plan to be updated", required: true)
    end

    response(200, "Updated", Schema.ref(:Plan))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => p_uuid} = params) do
    with %Plan{} = plan <- Enterprise.get_plan(p_uuid),
         {:ok, %Plan{} = plan} <- Enterprise.update_plan(plan, params) do
      conn |> render("plan.json", plan: plan)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/plans/{id}")
    summary("Delete a plan")
    description("Delete a plan")
    operation_id("delete_plan")

    parameters do
      id(:path, :string, "ID of the plan to be deleted")
    end

    response(200, "OK", Schema.ref(:Plan))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => p_uuid}) do
    with %Plan{} = plan <- Enterprise.get_plan(p_uuid),
         {:ok, %Plan{} = plan} <- Enterprise.delete_plan(plan) do
      conn |> render("plan.json", plan: plan)
    end
  end
end
