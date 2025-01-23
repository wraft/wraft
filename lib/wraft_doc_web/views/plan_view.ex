defmodule WraftDocWeb.Api.V1.PlanView do
  @moduledoc """
  View module for Plan controller.
  """
  use WraftDocWeb, :view

  def render("plan.json", %{plan: plan}) do
    %{
      id: plan.id,
      name: plan.name,
      description: plan.description,
      features: plan.features,
      limits: plan.limits,
      plan_id: plan.plan_id,
      plan_amount: plan.plan_amount,
      billing_interval: plan.billing_interval,
      product_id: plan.product_id,
      currency: plan.currency,
      updated_at: plan.updated_at,
      inserted_at: plan.inserted_at
    }
  end

  def render("plans.json", %{plans: plans}) do
    %{
      plans: render_many(plans, __MODULE__, "plan.json", as: :plan)
    }
  end

  def render("active_standard_plan.json", %{plans: plans}) do
    %{
      plans: render_many(plans, __MODULE__, "plan.json", as: :plan)
    }
  end
end
