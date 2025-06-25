defmodule WraftDoc.Repo.Migrations.UpdatePromptTable do
  use Ecto.Migration

  def up do
    alter table(:prompt) do
      remove(:model_id)
    end

    create(unique_index(:prompt, [:organisation_id, :title]))
  end

  def down do
    alter table(:prompt) do
      add(:model_id, references(:ai_model, type: :uuid, column: :id, on_delete: :delete_all))
    end

    drop(index(:prompt, [:organisation_id, :title]))
  end
end
