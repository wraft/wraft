defmodule WraftDoc.Repo.Migrations.FormRelatedTables do
  use Ecto.Migration

  def change do
    create table(:form, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:description, :string)
      add(:prefix, :string)
      add(:status, :string)
      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all))
      add(:creator_id, references(:user, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create table(:form_entry, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:data, :map)
      add(:status, :string)
      add(:form_id, references(:form, type: :uuid, on_delete: :nilify_all))
      add(:user_id, references(:user, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(unique_index(:form_entry, [:form_id, :user_id], name: :user_form_unique_index))

    rename(table(:content_type_field), to: table(:field))

    alter table(:field) do
      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all))
    end

    alter table(:field_type) do
      add(:validation, :map)
      add(:meta, :map)
    end

    create table(:form_mapping, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:mapping, :map)
      add(:pipe_stage_id, references(:pipe_stage, type: :uuid, on_delete: :nilify_all))
      add(:form_id, references(:form, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(
      unique_index(:form_mapping, [:form_id, :pipe_stage_id], name: :form_pipe_stage_unique_index)
    )

    create table(:form_field, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:validation, :map)

      add(
        :field_id,
        references(:field, type: :uuid, on_delete: :nilify_all)
      )

      add(:form_id, references(:form, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(unique_index(:form_field, [:form_id, :field_id], name: :form_field_unique_index))

    create table(:form_pipeline, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:form_id, references(:form, type: :uuid, on_delete: :nilify_all))
      add(:pipeline_id, references(:pipeline, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(
      unique_index(:form_pipeline, [:form_id, :pipeline_id], name: :form_pipeline_unique_index)
    )

    create table(:content_type_field, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:field_id, references(:field, type: :uuid, on_delete: :nilify_all))
      add(:content_type_id, references(:content_type, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(
      unique_index(:content_type_field, [:content_type_id, :field_id],
        name: :field_content_type_unique_index
      )
    )
  end
end
