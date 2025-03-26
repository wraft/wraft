defmodule WraftDoc.Documents.Reminder do
  @moduledoc """
  Schema for reminders
  """

  use WraftDoc.Schema
  alias __MODULE__

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
    |> validate_required([:reminder_date])
    |> validate_date(reminder)
  end

  @doc """
  Changeset for marking a reminder as sent.
  """
  def sent_changeset(reminder) do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> then(&change(reminder, status: :sent, sent_at: &1))
  end

  # Validates that the reminder date
  defp validate_date(
         %Ecto.Changeset{valid?: true, changes: %{reminder_date: reminder_date}} = changeset,
         reminder
       ) do
    today = Date.utc_today()

    with :ok <- check_future_date(reminder_date, today),
         :ok <- check_before_expiry_date(reminder_date, reminder) do
      changeset
    else
      {:error, message} ->
        add_error(changeset, :reminder_date, message)
    end
  end

  defp validate_date(changeset, _), do: changeset

  defp check_future_date(reminder_date, today) do
    if Date.compare(reminder_date, today) == :lt do
      {:error, "must be in the future"}
    else
      :ok
    end
  end

  defp check_before_expiry_date(reminder_date, %Reminder{
         content: %{meta: %{"type" => "contract", "expiry_date" => expiry_date}}
       }) do
    if Date.compare(reminder_date, Date.from_iso8601!(expiry_date)) == :gt do
      {:error, "must be before expiry date #{expiry_date}"}
    else
      :ok
    end
  end

  defp check_before_expiry_date(_, _), do: :ok
end
