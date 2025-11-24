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
      inserted_at: plan.inserted_at,
      coupon_id: plan.coupon_id || nil,
      coupon:
        if Ecto.assoc_loaded?(plan.coupon) do
          render_one(plan.coupon, __MODULE__, "coupon.json", as: :coupon)
        else
          nil
        end
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

  def render("coupon.json", %{coupon: coupon}) do
    %{
      id: coupon.id,
      name: coupon.name,
      description: coupon.description,
      coupon_id: coupon.coupon_id,
      coupon_code: coupon.coupon_code,
      amount: coupon.amount,
      currency: coupon.currency,
      type: coupon.type,
      status: coupon.status,
      recurring: coupon.recurring,
      maximum_recurring_intervals: coupon.maximum_recurring_intervals,
      expiry_date: coupon.expiry_date,
      usage_limit: coupon.usage_limit,
      times_used: coupon.times_used
    }
  end
end
