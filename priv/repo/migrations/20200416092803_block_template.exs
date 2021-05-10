defmodule WraftDoc.Repo.Migrations.BlockTemplate do
  use Ecto.Migration

  def change do
    create table(:block_template, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:title, :string, null: false)
      add(:body, :string)
      add(:serialised, :string)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
