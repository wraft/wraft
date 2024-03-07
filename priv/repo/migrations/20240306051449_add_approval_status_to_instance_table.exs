defmodule WraftDoc.Repo.Migrations.AddApprovalStatusToInstanceTable do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:approval_status, :boolean, null: false, default: false)
    end
  end
end
