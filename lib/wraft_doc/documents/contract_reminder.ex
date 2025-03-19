defmodule WraftDoc.Documents.ContractReminder do
  @moduledoc """
  Schema representing a contract reminder.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias WraftDoc.Documents.Instance

  @reminder_status [:pending, :sent, :cancelled]
  @notification_types [:email, :in_app, :both]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "contract_reminders" do
    belongs_to(:instance, Instance)

    field(:reminder_date, :date)
    field(:status, Ecto.Enum, values: @reminder_status, default: :pending)
    field(:message, :string)
    field(:notification_type, Ecto.Enum, values: @notification_types, default: :both)
    field(:recipients, {:array, :string}, default: [])
    field(:manual_date, :boolean, default: false)
    field(:sent_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Changeset for creating a new contract reminder.
  """
  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [
      :instance_id,
      :reminder_date,
      :status,
      :message,
      :notification_type,
      :recipients,
      :manual_date,
      :sent_at
    ])
    |> validate_required([:instance_id, :reminder_date, :message])
    |> validate_future_date(:reminder_date)
    |> foreign_key_constraint(:instance_id)
  end

  @doc """
  Changeset for updating an existing contract reminder.
  """
  def update_changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [
      :reminder_date,
      :status,
      :message,
      :notification_type,
      :recipients,
      :manual_date,
      :sent_at
    ])
    |> validate_future_date(:reminder_date)
  end

  @doc """
  Changeset for marking a reminder as sent.
  """
  def sent_changeset(reminder) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    change(reminder, status: :sent, sent_at: now)
  end

  defp validate_future_date(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      date ->
        today = Date.utc_today()

        if Date.compare(date, today) in [:gt, :eq] do
          changeset
        else
          add_error(changeset, field, "must be today or in the future")
        end
    end
  end

  @doc """
  Query to find upcoming reminders due for processing.
  Returns reminders that:
  - Have pending status
  - Have a reminder date of today or earlier
  - Haven't been sent yet
  """
  def upcoming_reminders_query do
    today = Date.utc_today()

    from(r in __MODULE__,
      where:
        r.status == :pending and
          r.reminder_date <= ^today and
          is_nil(r.sent_at),
      preload: [:instance]
    )
  end

  @doc """
  Query to find all reminders for a specific contract instance.
  """
  def for_instance(instance_id) do
    from(r in __MODULE__,
      where: r.instance_id == ^instance_id,
      order_by: [asc: r.reminder_date]
    )
  end
end
