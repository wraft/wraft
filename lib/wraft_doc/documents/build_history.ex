defmodule WraftDoc.Documents.Instance.History do
  @moduledoc """
    The instance build history model.
  """
  use WraftDoc.Schema

  alias __MODULE__

  @statuses [:enqueued, :executing, :success, :failed]
  @fields ~w(status exit_code start_time end_time delay)a

  schema "build_history" do
    field(:status, Ecto.Enum, values: @statuses)
    field(:exit_code, :integer)
    field(:start_time, :naive_datetime)
    field(:end_time, :naive_datetime)
    field(:delay, :integer)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%History{} = history, attrs \\ %{}) do
    history
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  def status_update_changeset(%History{} = history, attrs \\ %{}) do
    history
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end

  def final_update_changeset(%History{} = history, attrs \\ %{}) do
    history
    |> cast(attrs, @fields -- [:delay])
    |> validate_required(@fields -- [:delay])
    |> calculate_delay()
  end

  defp calculate_delay(
         %Ecto.Changeset{valid?: true, changes: %{end_time: end_time, start_time: start_time}} =
           changeset
       ) do
    end_time
    |> Timex.diff(start_time, :millisecond)
    |> then(&put_change(changeset, :delay, &1))
  end
end
