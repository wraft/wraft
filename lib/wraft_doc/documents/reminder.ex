defmodule WraftDoc.Documents.Reminder do
  @moduledoc """
  Schema for reminders
  """

  use WraftDoc.Schema

  @status ~w(pending sent cancelled)a
  @notification_types ~w(email in_app both)a
  @fields ~w(reminder_date status notification_type message recipients manual_date sent_at)a

  schema "reminders" do
    field(:reminder_date, :date)
    field(:status, Ecto.Enum, values: @status, default: :pending)
    field(:notification_type, Ecto.Enum, values: @notification_types, default: :both)
    field(:message, :string)
    field(:recipients, {:array, :string}, default: [])
    field(:manual_date, :boolean, default: false)
    field(:sent_at, :utc_datetime)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  @doc """
  Changeset for creating a new document reminder.
  """
  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, @fields)
    |> validate_required([:reminder_date, :message])
    |> validate_date()
  end

  @doc """
  Changeset for marking a reminder as sent.
  """
  def sent_changeset(reminder) do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> then(&change(reminder, status: :sent, sent_at: &1))
  end

  # Validates that the reminder date is in the future.
  defp validate_date(%Ecto.Changeset{valid?: true, changes: %{reminder_date: date}} = changeset) do
    today = Date.utc_today()

    if Date.compare(date, today) == :lt do
      add_error(changeset, :reminder_date, "must be in the future")
    else
      changeset
    end
  end

  defp validate_date(changeset), do: changeset
end
