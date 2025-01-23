defmodule WraftDocWeb.Api.V1.PlanView do
  @moduledoc """
  View module for Plan controller.
  """
  use WraftDocWeb, :view

  def render("plan.json", %{plan: %{custom: custom} = plan}) when custom != nil do
    %{
      id: plan.id,
      name: plan.name,
      description: plan.description,
      features: plan.features,
      custom_price_id: plan.custom_price_id,
      custom_price: %{
        custom_amount: custom.custom_amount,
        custom_period: custom.custom_period,
        custom_period_frequency: custom.custom_period_frequency
      },
      limits: plan.limits,
      product_id: plan.product_id,
      updated_at: plan.updated_at,
      inserted_at: plan.inserted_at
    }
  end

  def render("plan.json", %{plan: plan}) do
    %{
      id: plan.id,
      name: plan.name,
      description: plan.description,
      features: plan.features,
      yearly_product_id: plan.yearly_product_id,
      yearly_amount: plan.yearly_amount,
      monthly_product_id: plan.monthly_product_id,
      monthly_amount: plan.monthly_amount,
      limits: plan.limits,
      product_id: plan.product_id,
      updated_at: plan.updated_at,
      inserted_at: plan.inserted_at
    }
  end

  def render("plans.json", %{plans: plans}) do
    {enterprise_plans, regular_plans} = Enum.split_with(plans, &(&1.custom != nil))

    %{
      plans: render_many(regular_plans, __MODULE__, "plan.json", as: :plan),
      enterprise_plans: render_many(enterprise_plans, __MODULE__, "plan.json", as: :plan)
    }
  end

  def render("active_standard_plan.json", %{plans: plans}) do
    %{
      plans: render_many(plans, __MODULE__, "plan.json", as: :plan)
    }
  end
end
