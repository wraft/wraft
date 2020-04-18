defmodule WraftDoc.Repo.Migrations.CreateComment do
  use Ecto.Migration

  def change do
    create table(:comment) do
      add(:uuid, :uuid, null: false)
      add(:comment, :string, null: false)
      add(:is_parent, :boolean, null: false)
      add(:master, :string)
      add(:master_id, :string)
      add(:replay_count, :integer)
      add(:parent_id, references(:comment, on_delete: :nilify_all))
      add(:user_id, references(:user, on_delete: :nilify_all))
      add(:organisation_id, references(:organisation, on_delete: :nilify_all))
      timestamps()
    end
  end
end
