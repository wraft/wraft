defmodule WraftDoc.Repo.Migrations.AddControllFlow do
  use Ecto.Migration

  def change do
    alter table(:flow) do
      add(:controlled, :boolean, default: false)
      add(:control_data, :jsonb)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end
end
