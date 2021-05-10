defmodule WraftDoc.Repo.Migrations.CreateBuildHistoryTable do
  use Ecto.Migration

  def up do
    create table(:build_history, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:status, :string, null: false)
      add(:exit_code, :integer, null: false)
      add(:start_time, :naive_datetime, null: false)
      add(:end_time, :naive_datetime, null: false)
      add(:delay, :integer, null: false)
      add(:content_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end

  def down do
    drop_if_exists(table(:build_history))
  end
end
