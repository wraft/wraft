defmodule WraftDoc.Repo.Migrations.BlockTemplate do
  use Ecto.Migration

  def change do
    create table(:block_template) do
      add(:uuid, :uuid, null: false)
      add(:title, :string, null: false)
      add(:body, :string)
      add(:serialised, :string)
      add(:creator_id, references(:user, on_delete: :nilify_all))
      timestamps()
    end
  end
end
