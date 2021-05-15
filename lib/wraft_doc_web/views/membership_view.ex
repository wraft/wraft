defmodule WraftDocWeb.Api.V1.MembershipView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.PlanView

  def render("membership.json", %{membership: membership}) do
    %{
      id: membership.id,
      start_date: membership.start_date,
      end_date: membership.end_date,
      plan_duration: membership.plan_duration,
      is_expired: membership.is_expired,
      updated_at: membership.updated_at,
      inserted_at: membership.inserted_at,
      plan: render_one(membership.plan, PlanView, "plan.json", as: :plan)
    }
  end

  def render("only_membership.json", %{membership: membership}) do
    %{
      id: membership.id,
      start_date: membership.start_date,
      end_date: membership.end_date,
      plan_duration: membership.plan_duration,
      is_expired: membership.is_expired,
      updated_at: membership.updated_at,
      inserted_at: membership.inserted_at
    }
  end

  def render("info.json", %{message: message}) do
    %{
      info: message
    }
  end
end
