defmodule WraftDoc.Repo.Migrations.AddUniqueIndexBetweenPipeStageAndDataTemplate do
  use Ecto.Migration

  def change do
    drop(index("pipe_stage", [:pipeline_id, :content_type_id], name: :pipe_stages_unique_index))

    create(
      unique_index(:pipe_stage, [:pipeline_id, :data_template_id], name: :pipe_stages_unique_index)
    )
  end
end
