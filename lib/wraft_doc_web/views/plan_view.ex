defmodule WraftDocWeb.Api.V1.PlanView do
  @moduledoc """
  View module for Plan controller.
  """
  use WraftDocWeb, :view

  def render("plan.json", %{plan: plan}) do
    %{
      id: plan.uuid,
      name: plan.name,
      description: plan.description,
      yearly_amount: plan.yearly_amount,
      monthly_amount: plan.monthly_amount,
      updated_at: plan.updated_at,
      inserted_at: plan.inseted_at
    }
  end
end
