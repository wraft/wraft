defmodule WraftDoc.Repo.Migrations.CreateDocumentReminder do
  use Ecto.Migration

  def change do
    create table(:reminders, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:due_date, :utc_datetime)
      add(:status, :string)
      add(:content_id, references(:content, type: :uuid, on_delete: :delete_all))
      add(:creator_id, references(:user, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end
  end
end
