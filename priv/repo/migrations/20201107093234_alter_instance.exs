defmodule WraftDoc.Repo.Migrations.AlterInstance do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:vendor_id, references(:vendor, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end
end
