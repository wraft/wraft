defmodule WraftDoc.Repo.Migrations.CreateContractReminders do
  use Ecto.Migration

  def change do
    create table(:contract_reminders, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:instance_id, references(:content, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:reminder_date, :date, null: false)
      add(:status, :string, default: "pending", null: false)
      add(:message, :text, null: false)
      add(:notification_type, :string, default: "both", null: false)
      add(:recipients, {:array, :string}, default: [])
      add(:manual_date, :boolean, default: false)
      add(:sent_at, :utc_datetime)

      timestamps()
    end

    create(index(:contract_reminders, [:instance_id]))
    create(index(:contract_reminders, [:status, :reminder_date]))
    create(index(:contract_reminders, [:reminder_date]))
  end
end
