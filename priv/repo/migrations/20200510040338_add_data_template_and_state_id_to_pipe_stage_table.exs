defmodule WraftDoc.Repo.Migrations.AddDataTemplateAndStateIdToPipeStageTable do
  use Ecto.Migration

  def up do
    alter table(:pipe_stage) do
      add(:data_template_id, references(:data_template))
      add(:state_id, references(:state))
      add(:creator_id, references(:user))

      timestamps
    end
  end

  def down do
    alter table(:pipe_stage) do
      remove(:data_template_id)
      remove(:state_id)
      remove(:creator_id)
      remove(:inserted_at)
      remove(:updated_at)
    end
  end
end
