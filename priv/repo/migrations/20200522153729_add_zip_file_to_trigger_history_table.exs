defmodule WraftDoc.Repo.Migrations.AddZipFileToTriggerHistoryTable do
  use Ecto.Migration

  def up do
    alter table(:trigger_history) do
      add(:zip_file, :string)
    end
  end

  def down do
    alter table(:trigger_history) do
      remove(:zip_file)
    end
  end
end
