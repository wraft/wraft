defmodule WraftDocWeb.EnterprisePlanAdmin do
  @moduledoc """
  Admin panel for custom enterprise plan.
  """

  import Ecto.Query
  use Ecto.Schema

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan

  def plural_name(_), do: "Enterprise Plans"

  def singular_name(_), do: "Enterprise Plan"

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      description: %{name: "Description", value: fn x -> x.description end},
      custom: %{
        name: "amount",
        value: fn x -> if x.custom != nil, do: x.custom.custom_amount end
      },
      custom_period: %{
        name: "duration",
        value: fn x ->
          if x.custom != nil,
            do: "#{x.custom.custom_period_frequency} x #{x.custom.custom_period}"
        end
      }
    ]
  end

  def form_fields(_) do
    [
      name: %{
        label: "Name",
        required: true
      },
      description: %{label: "Description", required: true, type: :textarea},
      limits: %{
        label: "Limits",
        help_text: "Define usage limits for this plan."
      },
      custom: %{
        label: "Custom",
        help_text: """
          Define custom pricing for this plan.
          Frequency of custom period. For example, if you select 'month' as the custom period and set the frequency to 3, the plan will be billed every 3 months.
        """
      }
    ]
  end

  def ordering(_) do
    [desc: :inserted_at]
  end

  def custom_index_query(_conn, _schema, _query) do
    from(p in Plan,
      where: not is_nil(p.custom)
    )
  end

  def create_changeset(schema, attrs) do
    Plan.custom_plan_changeset(schema, attrs)
  end

  def update_changeset(schema, attrs) do
    Plan.custom_plan_changeset(schema, attrs)
  end

  def insert(conn, changeset) do
    params = conn.params["plan"]

    conn.assigns[:admin_session]
    |> Enterprise.create_plan(params)
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end

  def update(conn, changeset) do
    params = conn.params["plan"]
    plan = changeset.data

    conn.assigns[:admin_session]
    |> Enterprise.update_plan(plan, params)
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end

  def delete(_conn, changeset) do
    changeset.data
    |> Enterprise.delete_plan()
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end
end
