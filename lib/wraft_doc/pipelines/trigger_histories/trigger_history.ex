defmodule WraftDoc.Pipelines.TriggerHistories.TriggerHistory do
  @moduledoc """
  The pipeline trigger history model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :data,
             :error,
             :state,
             :pipeline_id,
             :creator_id,
             :start_time,
             :end_time,
             :duration
           ]}
  def states,
    do: [enqued: 1, executing: 2, pending: 3, partially_completed: 4, success: 5, failed: 6]

  schema "trigger_history" do
    field(:data, :map)
    field(:error, :map, default: %{})
    field(:state, :integer)
    field(:start_time, :naive_datetime)
    field(:end_time, :naive_datetime)
    field(:duration, :integer)
    field(:zip_file, :string)
    belongs_to(:pipeline, WraftDoc.Pipelines.Pipeline)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  @doc """
  Get the state value of a trigger history from its integer.
  """
  @spec get_state(TriggerHistory.t()) :: nil | binary
  def get_state(%TriggerHistory{state: state_int}) do
    states()
    |> Enum.find(fn {_state, int} -> int == state_int end)
    |> case do
      {state, _} ->
        Atom.to_string(state)

      _ ->
        nil
    end
  end

  def get_state(_), do: nil

  def changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:data, :state, :creator_id])
    |> validate_required([:data, :state, :creator_id])
  end

  def hook_changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:data, :state])
    |> validate_required([:data, :state])
  end

  def trigger_start_changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:state, :start_time])
    |> validate_required([:state, :start_time])
  end

  def update_changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:error, :state, :start_time, :zip_file])
    |> validate_required([:state, :error])
  end

  def trigger_end_changeset(%TriggerHistory{} = trigger, attrs \\ %{}) do
    trigger
    |> cast(attrs, [:end_time])
    |> validate_required([:end_time])
    |> calculate_duration(trigger)
  end

  defp calculate_duration(
         %Ecto.Changeset{valid?: true, changes: %{end_time: end_time}} = changeset,
         %TriggerHistory{start_time: start_time}
       )
       when is_nil(start_time) == false do
    put_change(changeset, :duration, Timex.diff(end_time, start_time, :millisecond))
  end

  defp calculate_duration(changeset, _), do: changeset
end
