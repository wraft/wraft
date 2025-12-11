defmodule WraftDocWeb.Schemas.Plan do
  @moduledoc """
  Schema for Plan request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Plan do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Plan",
      description: "A plan",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Plan id"},
        name: %Schema{type: :string, description: "Plan name"},
        description: %Schema{type: :string, description: "Plan description"},
        features: %Schema{
          type: :array,
          description: "Plan features",
          items: %Schema{type: :string}
        },
        plan_id: %Schema{type: :string, description: "Paddle price ID"},
        plan_amount: %Schema{type: :string, description: "Amount of the plan"},
        product_id: %Schema{type: :string, description: "Paddle product ID"},
        billing_interval: %Schema{type: :string, description: "Billing interval"},
        limits: %Schema{type: :object, description: "Limits of the plan"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the plan inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the plan last updated",
          format: "ISO-8601"
        }
      },
      example: %{
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
      }
    })
  end

  defmodule EnterprisePlan do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Enterprise Plan",
      description: "A custom enterprise plan",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Plan id"},
        name: %Schema{type: :string, description: "Plan name"},
        description: %Schema{type: :string, description: "Plan description"},
        features: %Schema{
          type: :array,
          description: "Plan features",
          items: %Schema{type: :string}
        },
        plan_id: %Schema{type: :string, description: "Custom price ID"},
        limits: %Schema{type: :object, description: "Limits of the plan"},
        custom: %Schema{type: :object, description: "Custom plan"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the plan inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the plan last updated",
          format: "ISO-8601"
        }
      },
      example: %{
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
      }
    })
  end

  defmodule PlanRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Plan request",
      description: "Plan create/update request",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Plan name"},
        description: %Schema{type: :string, description: "Plan description"},
        yearly_amount: %Schema{type: :string, description: "Yearly amount of the plan"},
        monthly_amount: %Schema{type: :string, description: "Monthly amount of the plan"}
      },
      required: [:name, :description],
      example: %{
        name: "Basic",
        description: "A basic plan",
        yearly_amount: "10",
        monthly_amount: "6"
      }
    })
  end

  defmodule PlanResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Plan Response",
      description: "Response containing either a regular plan or an enterprise plan",
      type: :object,
      properties: %{
        plan: Plan,
        enterprise_plan: EnterprisePlan
      }
    })
  end

  defmodule Plans do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All plans",
      description: "All plans that have been created",
      type: :object,
      properties: %{
        plan: %Schema{type: :array, description: "Regular plans", items: Plan},
        enterprise_plans: %Schema{
          type: :array,
          description: "Enterprise plans",
          items: EnterprisePlan
        }
      }
    })
  end
end
