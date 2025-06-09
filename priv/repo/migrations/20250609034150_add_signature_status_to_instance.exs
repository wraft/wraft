defmodule WraftDoc.Repo.Migrations.AddSignatureStatusToInstance do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:signature_status, :boolean, default: false)
    end
  end
end
