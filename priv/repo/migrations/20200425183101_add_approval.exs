defmodule WraftDoc.Repo.Migrations.AddApproval do
  use Ecto.Migration

  def change do
    alter table(:approval_system) do
      add(:approved, :boolean, default: false)
    end
  end
end
