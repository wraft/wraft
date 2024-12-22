defmodule WraftDocWeb.Api.V1.PlanView do
  @moduledoc """
  View module for Plan controller.
  """
  use WraftDocWeb, :view
  alias __MODULE__

  def render("plan.json", %{plan: %{custom: custom} = plan}) when custom != nil do
    %{
      id: plan.id,
      name: plan.name,
      description: plan.description,
      custom_price_id: plan.custom_price_id,
      custom_price: %{
        custom_amount: custom.custom_amount,
        custom_period: custom.custom_period,
        custom_period_frequency: custom.custom_period_frequency
      },
      limits: plan.limits,
      product_id: plan.paddle_product_id,
      updated_at: plan.updated_at,
      inserted_at: plan.inserted_at
    }
  end

  def render("plan.json", %{plan: plan}) do
    %{
      id: plan.id,
      name: plan.name,
      description: plan.description,
      yearly_price_id: plan.yearly_price_id,
      yearly_amount: plan.yearly_amount,
      monthly_price_id: plan.monthly_price_id,
      monthly_amount: plan.monthly_amount,
      limits: plan.limits,
      product_id: plan.paddle_product_id,
      updated_at: plan.updated_at,
      inserted_at: plan.inserted_at
    }
  end

  def render("plans.json", %{plans: plans}) do
    render_many(plans, PlanView, "plan.json", as: :plan)
  end
end
