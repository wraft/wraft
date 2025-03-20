defmodule WraftDoc.Repo.Migrations.CreateDocumentReminder do
  use Ecto.Migration

  def change do
    create table(:reminders, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:reminder_date, :date, null: false)
      add(:status, :string, default: "pending", null: false)
      add(:message, :text, null: false)
      add(:notification_type, :string, default: "both", null: false)
      add(:recipients, {:array, :string}, default: [])
      add(:manual_date, :boolean, default: false)
      add(:sent_at, :utc_datetime)
      add(:content_id, references(:content, type: :uuid, on_delete: :delete_all))
      add(:creator_id, references(:user, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(index(:reminders, [:content_id]))
    create(index(:reminders, [:status, :reminder_date]))
    create(index(:reminders, [:reminder_date]))
  end
end
