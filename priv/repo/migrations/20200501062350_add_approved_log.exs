defmodule WraftDoc.Repo.Migrations.AddApprovedLog do
  use Ecto.Migration

  def change do
    alter table(:approval_system) do
      add(:approved_log, :naive_datetime)
    end
  end
end
