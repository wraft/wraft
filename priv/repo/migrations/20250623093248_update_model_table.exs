defmodule WraftDoc.Repo.Migrations.UpdateModelTable do
  use Ecto.Migration

  def up do
    alter table(:ai_model) do
      add(:is_default, :boolean, default: false)
    end

    drop(index(:ai_model, [:name]))
    drop(index(:ai_model, [:model_name]))

    create(unique_index(:ai_model, [:organisation_id, :name]))
    create(unique_index(:ai_model, [:organisation_id, :model_name]))

    create(
      unique_index(:ai_model, [:organisation_id],
        where: "is_default = true",
        name: :unique_default_model_per_organisation
      )
    )

    alter(table(:ai_model_log)) do
      remove(:model_id)
      remove(:prompt_id)
    end
  end

  def down do
    alter table(:ai_model) do
      remove(:is_default)
    end

    alter(table(:ai_model_log)) do
      add(:model_id, references(:ai_model, type: :uuid, on_delete: :nothing))
      add(:prompt_id, references(:prompt, type: :uuid, on_delete: :nothing))
    end
  end
end
