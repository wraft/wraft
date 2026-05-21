defmodule WraftDoc.Repo.Migrations.AddErrorLogToBuildHistory do
  use Ecto.Migration

  def up do
    alter table(:build_history) do
      add(:error_log, :text)
    end
  end

  def down do
    alter table(:build_history) do
      remove(:error_log)
    end
  end
end
