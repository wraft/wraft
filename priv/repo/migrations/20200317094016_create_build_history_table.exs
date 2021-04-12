defmodule WraftDoc.Repo.Migrations.CreateBuildHistoryTable do
  use Ecto.Migration

  def up do
    create table(:build_history) do
      add(:uuid, :uuid, null: false)
      add(:status, :string, null: false)
      add(:exit_code, :integer, null: false)
      add(:start_time, :naive_datetime, null: false)
      add(:end_time, :naive_datetime, null: false)
      add(:delay, :integer, null: false)
      add(:content_id, references(:content))
      add(:creator_id, references(:user))
      timestamps()
    end
  end

  def down do
    drop_if_exists(table(:build_history))
  end
end
