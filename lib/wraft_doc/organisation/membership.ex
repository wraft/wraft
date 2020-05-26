defmodule WraftDoc.Enterprise.Membership do
  @moduledoc """
  The membership model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "membership" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:start_date, :naive_datetime)
    field(:end_date, :naive_datetime)
    field(:plan_duration, :integer, default: 0)
    belongs_to(:plan, WraftDoc.Enterprise.Plan)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%Membership{} = membership, attrs \\ %{}) do
    membership
    |> cast(attrs, [:start_date, :end_date, :plan_id, :organisation_id])
    |> calculate_plan_duration(membership)
    |> validate_plan_duration_format()
    |> validate_required([:start_date, :end_date, :plan_duration, :plan_id, :organisation_id])
    |> unique_constraint(:plan_id,
      name: :membership_unique_index,
      message: "You already have a membership.!"
    )
  end

  def update_changeset(%Membership{} = membership, attrs \\ %{}) do
    membership
    |> cast(attrs, [:start_date, :end_date])
    |> calculate_plan_duration(membership)
    |> validate_plan_duration_format()
    |> validate_required([:start_date, :end_date])
  end

  # Calculate duration of a membership
  @spec calculate_plan_duration(Changeset.t(), %Membership{}) :: Changeset.t()
  defp calculate_plan_duration(
         %Ecto.Changeset{valid?: true, changes: %{start_date: start_date, end_date: end_date}} =
           changeset,
         _membership
       )
       when is_nil(start_date) == false and is_nil(end_date) == false do
    duration = Timex.diff(end_date, start_date, :days)
    put_change(changeset, :plan_duration, duration)
  end

  defp calculate_plan_duration(
         %Ecto.Changeset{valid?: true, changes: %{end_date: end_date}} = changeset,
         %Membership{start_date: start_date}
       )
       when is_nil(end_date) == false do
    duration = Timex.diff(end_date, start_date, :days)
    put_change(changeset, :plan_duration, duration)
  end

  defp calculate_plan_duration(
         %Ecto.Changeset{valid?: true, changes: %{start_date: start_date}} = changeset,
         %Membership{end_date: end_date}
       )
       when is_nil(start_date) == false do
    duration = Timex.diff(end_date, start_date, :days)
    put_change(changeset, :plan_duration, duration)
  end

  defp calculate_plan_duration(changeset, _), do: changeset

  # Validate the format of the plan duration.
  # It should be a positive integer.
  @spec validate_plan_duration_format(Changeset.t()) :: Changeset.t()
  defp validate_plan_duration_format(
         %Ecto.Changeset{valid?: true, changes: %{plan_duration: plan_duration}} = changeset
       ) do
    IO.inspect(changeset)
    plan_duration = plan_duration |> Integer.to_string()

    Regex.match?(~r/^[0-9]\d*$/, plan_duration)
    |> case do
      true ->
        changeset

      false ->
        add_error(changeset, :plan_duration, "Duration should be a positive number.!")
    end
  end

  defp validate_plan_duration_format(changeset), do: changeset
end
