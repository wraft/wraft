defmodule WraftDoc.Repo.Migrations.AddStateIdToContentTable do
  use Ecto.Migration

  def up do
    alter table(:content) do
      add(:state_id, references(:flow))
    end
  end

  def down do
    alter table(:content) do
      remove(:state_id)
    end
  end
end
