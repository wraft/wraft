defmodule WraftDoc.Repo.Migrations.ContentCollaboration do
  use Ecto.Migration

  def up do
    drop_if_exists(table(:content_collab))

    create table(:content_collaboration, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:role, :string)
      add(:status, :string)
      add(:content_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:state_id, references(:state, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :guest_user_id,
        references(:guest_user, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create(unique_index(:content_collaboration, [:content_id, :user_id, :state_id]))
    create(unique_index(:content_collaboration, [:content_id, :guest_user_id, :state_id]))
  end

  def down do
    drop_if_exists(table(:content_collaboration))
  end
end
