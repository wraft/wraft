defmodule WraftDoc.Repo.Migrations.CreateNotification do
  use Ecto.Migration

  def change do
    create table(:notification, primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:read_at, :naive_datetime)
      add(:read, :boolean)
      add(:action, :string)
      add(:notifiable_id, :uuid)
      add(:notifiable_type, :string)
      add(:recipient_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:actor_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end
  end
end
