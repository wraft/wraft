defmodule WraftDoc.Documents.Reminder do
  @moduledoc """
  Schema for reminders
  """

  use WraftDoc.Schema

  @status ~w(pending completed)a

  schema "reminders" do
    field(:due_date, :utc_datetime)
    field(:status, Ecto.Enum, values: @status, default: :pending)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:due_date, :content_id, :creator_id])
    |> validate_required([:due_date, :content_id, :creator_id])
  end
end
