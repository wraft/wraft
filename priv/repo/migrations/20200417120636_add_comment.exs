defmodule WraftDoc.Repo.Migrations.CreateComment do
  use Ecto.Migration

  def change do
    create table(:comment, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:comment, :string, null: false)
      add(:is_parent, :boolean, null: false)
      add(:master, :string)
      add(:master_id, :string)
      add(:replay_count, :integer)
      add(:parent_id, references(:comment, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end
  end
end
