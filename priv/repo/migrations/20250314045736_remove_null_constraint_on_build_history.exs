defmodule WraftDoc.Repo.Migrations.RemoveNullConstraintOnBuildHistory do
  use Ecto.Migration

  def change do
    alter table(:build_history) do
      modify(:status, :string, null: true)
      modify(:exit_code, :integer, null: true)
      modify(:start_time, :naive_datetime, null: true)
      modify(:end_time, :naive_datetime, null: true)
      modify(:delay, :integer, null: true)
    end
  end
end
