defmodule WraftDoc.Repo.Migrations.AddVendorIdToContent do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:vendor_id, references(:vendors, type: :uuid, on_delete: :nilify_all))
    end

    create(index(:content, [:vendor_id]))
  end
end
