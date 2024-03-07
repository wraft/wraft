defmodule WraftDoc.Repo.Migrations.ContentCollab do
  use Ecto.Migration

  def change do
    create table(:content_collab, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:roles, :string)
      add(:content_id, references(:content, type: :uuid, on_delete: :nilify_all))
      add(:user_id, references(:user, type: :uuid, on_delete: :nilify_all))
      add(:state_id, references(:state, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(
      unique_index(:content_collab, [:user_id, :state_id, :content_id],
        name: :content_collab_user_state_content_unique_index
      )
    )
  end
end
