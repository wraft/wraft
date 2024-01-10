defmodule WraftDocWeb.MembershipAdmin do
  @moduledoc """
  Admin panel for membership
  """
  alias WraftDoc.{Enterprise.Organisation, Enterprise.Plan, Repo}
  import Ecto.Query

  def index(_) do
    [
      organisation_id: %{
        name: "Organisation",
        value: fn x -> organisation_name(x.organisation) end
      },
      start_date: %{name: "Start date", value: fn x -> x.start_date end},
      end_date: %{name: "End date", value: fn x -> x.end_date end},
      plan_duration: %{name: "Plan duratin", value: fn x -> x.plan_duration end},
      plan_id: %{name: "Plan name", value: fn x -> plan_name(x.plan) end}
    ]
  end

  def form_fields(_) do
    [
      organisation_id: %{label: "Organisation", choices: list_organisations()},
      start_date: %{label: "Start date", type: :naive_datetime},
      end_date: %{label: "End date", type: :naive_datetime},
      plan_duration: %{label: "Plan duration", type: :integer},
      plan_id: %{label: "Plan", choices: list_plans()}
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(q in query, preload: [:organisation, :plan])
  end

  def ordering(_) do
    [desc: :inserted_at]
  end

  defp plan_name(%{name: name}) do
    name
  end

  defp plan_name(_), do: nil

  defp organisation_name(%{name: name}) do
    name
  end

  defp organisation_name(_), do: nil

  defp list_organisations do
    Organisation |> Repo.all() |> Enum.map(fn x -> {x.name, x.id} end)
  end

  defp list_plans do
    Plan |> Repo.all() |> Enum.map(fn x -> {x.name, x.id} end)
  end
end
