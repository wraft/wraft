defmodule WraftDocWeb.MembershipAdmin do
  @moduledoc """
  Admin panel for membership
  """
  def index(_) do
    [
      plan_id: %{name: "Plan name", value: fn x -> plan_name(x) end},
      start_date: %{name: "Start date", value: fn x -> x.start_date end},
      end_date: %{name: "End date", value: fn x -> x.end_date end},
      plan_duration: %{name: "Plan duratin", value: fn x -> x.plan_duratoin end}
    ]
  end

  defp plan_name(%{name: name}) do
    name
  end

  defp plan_name(_), do: nil
end
