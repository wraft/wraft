defmodule WraftDocWeb.PlanAdmin do
  @moduledoc """
  Admin panel for plan module
  """
  import Ecto.Query
  use Ecto.Schema

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Repo

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      description: %{name: "Description", value: fn x -> x.description end},
      yearly_amount: %{name: "Yearly amount", value: fn x -> x.yearly_amount end},
      monthly_amount: %{name: "Monthly amount", value: fn x -> x.monthly_amount end}
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      description: %{label: "Description", type: :textarea},
      yearly_amount: %{label: "Yearly amount", type: :string, required: true},
      monthly_amount: %{label: "Monthly amount", type: :string, required: true},
      features: %{
        label: "Features"
      },
      limits: %{
        label: "Limits",
        required: true,
        help_text: "Define usage limits for this plan."
      }
    ]
  end

  def default_actions(_schema) do
    [:new, :delete]
  end

  def ordering(_) do
    [desc: :inserted_at]
  end

  def custom_index_query(_conn, _schema, _query) do
    from(p in Plan,
      where: is_nil(p.custom),
      where: p.is_active? == true
    )
  end

  def create_changeset(schema, attrs) do
    Plan.plan_changeset(schema, attrs)
  end

  def update_changeset(schema, attrs) do
    Plan.plan_changeset(schema, attrs)
  end

  def insert(conn, changeset) do
    current_user = conn.assigns[:admin_session]

    conn.params["plan"]
    |> then(&Enterprise.create_plan(current_user, &1))
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        custom_error(changeset, error)
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
        custom_error(changeset, error)
    end
  end

  def delete(_conn, changeset) do
    changeset
    |> Ecto.Changeset.change(%{is_active?: false})
    |> Repo.update()
    |> case do
      {:ok, plan} ->
        {:ok, plan}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp custom_error(changeset, error) do
    {:error, {changeset, error}}
  end
end
