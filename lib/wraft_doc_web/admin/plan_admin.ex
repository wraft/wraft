defmodule WraftDocWeb.PlanAdmin do
  @moduledoc """
  Admin panel for plan module
  """

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      description: %{name: "Description", value: fn x -> x.description end},
      yearly_amount: %{name: "Yearly amount", vlue: fn x -> x.yearly_amount end},
      monthly_amount: %{name: "Monthly amount", value: fn x -> x.monthly_amount end}
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      description: %{label: "Description", type: :textarea},
      yearly_amount: %{label: "Yearly amount", type: :integer},
      monthly_amount: %{label: "Monthly amount", type: :integer}
    ]
  end

  def ordering(_) do
    [desc: :inserted_at]
  end
end
