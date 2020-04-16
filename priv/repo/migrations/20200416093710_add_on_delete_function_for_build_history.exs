defmodule WraftDoc.Repo.Migrations.AddOnDeleteFunctionForBuildHistory do
  use Ecto.Migration

  def up do
    drop(constraint(:build_history, "build_history_content_id_fkey"))

    alter table(:build_history) do
      modify(:content_id, references(:content, on_delete: :nilify_all))
    end
  end

  def down do
    drop(constraint(:build_history, "build_history_content_id_fkey"))

    alter table(:build_history) do
      modify(:content_id, references(:content))
    end
  end
end
