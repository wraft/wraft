defmodule WraftDoc.Repo.Migrations.CreateNotification do
  use Ecto.Migration

  def change do
    create table(:notification) do
      add(:uuid, :uuid, null: false, autogenerate: true)
      add(:read_at, :naive_datetime)
      add(:read, :boolean)
      add(:action, :string)
      add(:notifiable_id, :integer)
      add(:notifiable_type, :string)

      timestamps()
    end
  end
end
