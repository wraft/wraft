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
    field(:plan_duration, :integer)
    field(:is_expired, :boolean, default: false)
    belongs_to(:plan, WraftDoc.Enterprise.Plan)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%Membership{} = membership, attrs \\ %{}) do
    membership
    |> cast(attrs, [:start_date, :end_date, :plan_id, :organisation_id, :plan_duration])
    |> validate_number(:plan_duration, greater_than_or_equal_to: 14)
    |> validate_required([:start_date, :end_date, :plan_duration, :plan_id, :organisation_id])
    |> unique_constraint(:plan_id,
      name: :membership_unique_index,
      message: "You already have a membership.!"
    )
  end

  def update_changeset(%Membership{} = membership, attrs \\ %{}) do
    attrs = attrs |> Map.put(:is_expired, false)

    membership
    |> cast(attrs, [:start_date, :end_date, :plan_duration, :plan_id, :is_expired])
    |> validate_number(:plan_duration, greater_than_or_equal_to: 30)
    |> validate_required([:start_date, :end_date, :plan_id])
  end

  def expired_changeset(%Membership{} = membership) do
    membership
    |> cast(%{is_expired: true}, [:is_expired])
  end

  # # Calculate duration of a membership
  # @spec calculate_plan_duration(Changeset.t(), %Membership{}) :: Changeset.t()
  # defp calculate_plan_duration(
  #        %Ecto.Changeset{valid?: true, changes: %{start_date: start_date, end_date: end_date}} =
  #          changeset,
  #        _membership
  #      )
  #      when is_nil(start_date) == false and is_nil(end_date) == false do
  #   duration = Timex.diff(end_date, start_date, :days)
  #   put_change(changeset, :plan_duration, duration)
  # end

  # defp calculate_plan_duration(
  #        %Ecto.Changeset{valid?: true, changes: %{end_date: end_date}} = changeset,
  #        %Membership{start_date: start_date}
  #      )
  #      when is_nil(end_date) == false do
  #   duration = Timex.diff(end_date, start_date, :days)
  #   put_change(changeset, :plan_duration, duration)
  # end

  # defp calculate_plan_duration(
  #        %Ecto.Changeset{valid?: true, changes: %{start_date: start_date}} = changeset,
  #        %Membership{end_date: end_date}
  #      )
  #      when is_nil(start_date) == false do
  #   duration = Timex.diff(end_date, start_date, :days)
  #   put_change(changeset, :plan_duration, duration)
  # end

  # defp calculate_plan_duration(changeset, _), do: changeset
end
