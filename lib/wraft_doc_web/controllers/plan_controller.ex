defmodule WraftDocWeb.Api.V1.PlanController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  import Ecto.Query, warn: false

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Plan, as: PlanSchema

  tags(["Plans"])

  operation(:index,
    summary: "Plan index",
    description: "List all plans created so far",
    operation_id: "plan_index",
    responses: [
      ok: {"OK", "application/json", PlanSchema.Plans},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    plans = Enterprise.plan_index()
    render(conn, "plans.json", plans: plans)
  end

  operation(:active_plans,
    summary: "Active Standard Plans",
    description: "List all active standard plans",
    operation_id: "active_plans",
    responses: [
      ok: {"OK", "application/json", PlanSchema.Plans},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec active_plans(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def active_plans(conn, _params) do
    with plans <- Enterprise.active_plans() do
      render(conn, "active_standard_plan.json", plans: plans)
    end
  end

  operation(:show,
    summary: "Show Plan",
    description: "Show a plan",
    operation_id: "show_plan",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the plan", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", PlanSchema.PlanResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => p_uuid}) do
    with %Plan{} = plan <- Enterprise.get_plan(p_uuid) do
      render(conn, "plan.json", plan: plan)
    end
  end
end
