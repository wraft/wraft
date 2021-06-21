defmodule WraftDoc.Repo.Migrations.AddCreator do
  use Ecto.Migration

  def change do
    alter table(:collection_form) do
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:organisation_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    alter table(:collection_form_field) do
      add(:meta, :jsonb)
    end
  end
end
