defmodule WraftDoc.Repo.Migrations.CreatePipelineTable do
  use Ecto.Migration

  def up do
    create table(:pipeline) do
      add(:uuid, :uuid, null: false)
      add(:name, :string)
      add(:api_route, :string)
      add(:creator_id, references(:user, on_delete: :nilify_all))
      add(:organisation_id, references(:organisation, on_delete: :delete_all))

      timestamps()
    end

    create table(:pipe_stage) do
      add(:uuid, :uuid, null: false)
      add(:pipeline_id, references(:pipeline, on_delete: :delete_all))
      add(:content_type_id, references(:content_type, on_delete: :delete_all))
    end

    create table(:hook_trigger_history) do
      add(:uuid, :uuid, null: false)
      add(:meta, :jsonb)
      add(:pipeline_id, references(:pipeline))

      timestamps()
    end

    create(
      unique_index(:pipeline, [:name, :organisation_id], name: :organisation_pipeline_unique_index)
    )

    create(
      unique_index(:pipe_stage, [:pipeline_id, :content_type_id], name: :pipe_stages_unique_index)
    )
  end

  def down do
    drop_if_exists(table(:hook_trigger_history))
    drop_if_exists(table(:pipe_stage))
    drop_if_exists(table(:pipeline))
  end
end
