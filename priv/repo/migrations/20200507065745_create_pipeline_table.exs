defmodule WraftDoc.Repo.Migrations.CreatePipelineTable do
  use Ecto.Migration

  def up do
    create table(:pipeline, primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:name, :string)
      add(:api_route, :string)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create table(:pipe_stage, primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:pipeline_id, references(:pipeline, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :content_type_id,
        references(:content_type, type: :uuid, column: :id, on_delete: :nilify_all)
      )
    end

    create table(:hook_trigger_history, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:meta, :jsonb)
      add(:pipeline_id, references(:pipeline, type: :uuid, column: :id, on_delete: :nilify_all))

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
