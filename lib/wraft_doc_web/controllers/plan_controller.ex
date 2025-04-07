defmodule WraftDocWeb.Api.V1.PlanController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  import Ecto.Query, warn: false

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan

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
            features(:array, "Plan features")
            plan_id(:string, "Paddle price ID")
            plan_amount(:string, "Amount of the plan")
            product_id(:string, "Paddle product ID")
            billing_interval(:string, "Billing interval")
            limits(:map, "Limits of the plan")
            inserted_at(:string, "When was the plan inserted", format: "ISO-8601")
            updated_at(:string, "When was the plan last updated", format: "ISO-8601")
          end

          example(%{
            id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
            name: "Basic",
            description: "A basic plan",
            features: ["Feature 1", "Feature 2"],
            plan_id: "123456789",
            plan_amount: "6",
            product_id: "123456789",
            billing_interval: "month",
            limits: %{
              instance_create: 25,
              content_type_create: 25,
              organisation_create: 25,
              organisation_invite: 25
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      EnterprisePlan:
        swagger_schema do
          title("Enterprise Plan")
          description("A custom enterprise plan")

          properties do
            id(:string, "Plan id")
            name(:string, "Plan name")
            description(:string, "Plan description")
            features(:array, "Plan features")
            plan_id(:string, "Custom price ID")
            limits(:map, "Limits of the plan")
            custom(:map, "Custom plan")
            inserted_at(:string, "When was the plan inserted", format: "ISO-8601")
            updated_at(:string, "When was the plan last updated", format: "ISO-8601")
          end

          example(%{
            id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
            name: "Basic",
            description: "A basic plan",
            features: ["Feature 1", "Feature 2"],
            plan_id: "123456789",
            limits: %{
              instance_create: 25,
              content_type_create: 25,
              organisation_create: 25,
              organisation_invite: 25
            },
            custom: %{
              custom_amount: "499",
              custom_period: "month",
              custom_period_frequency: 4
            },
            organisation_id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
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
            yearly_amount(:string, "Yearly amount of the plan")
            monthly_amount(:string, "Monthly amount of the plan")
          end

          example(%{
            name: "Basic",
            description: "A basic plan",
            yearly_amount: "10",
            monthly_amount: "6"
          })
        end,
      PlanResponse:
        swagger_schema do
          title("Plan Response")
          description("Response containing either a regular plan or an enterprise plan")

          properties do
            plan(Schema.ref(:Plan), "Regular Plan")
            enterprise_plan(Schema.ref(:EnterprisePlan), "Enterprise Plan")
          end
        end,
      Plans:
        swagger_schema do
          title("All plans")
          description("All plans that have been created")

          properties do
            plan(:array, "Regular plans", items: Schema.ref(:Plan))
            enterprise_plans(:array, "Enterprise plans", items: Schema.ref(:EnterprisePlan))
          end
        end
    }
  end

  swagger_path :index do
    get("/plans")
    summary("Plan index")
    description("List all plans created so far")
    operation_id("plan_index")

    response(200, "OK", Schema.ref(:Plans))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    plans = Enterprise.plan_index()
    render(conn, "plans.json", plans: plans)
  end

  swagger_path :active_plans do
    get("/plans/active_plans")
    summary("Active Standard Plans")
    description("List all active standard plans")
    operation_id("active_plans")

    response(200, "OK", Schema.ref(:Plans))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec active_plans(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def active_plans(conn, _params) do
    with plans <- Enterprise.active_plans() do
      render(conn, "active_standard_plan.json", plans: plans)
    end
  end

  swagger_path :show do
    get("/plans/{id}")
    summary("Show Plan")
    description("Show a plan")
    operation_id("show_plan")

    parameters do
      id(:path, :string, "ID of the plan")
    end

    response(200, "OK", Schema.ref(:PlanResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => p_uuid}) do
    with %Plan{} = plan <- Enterprise.get_plan(p_uuid) do
      render(conn, "plan.json", plan: plan)
    end
  end
end
