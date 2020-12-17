defmodule WraftDoc.Repo.Migrations.AlterInstance do
  use Ecto.Migration

  def change do
   alter table(:content) do
    add :vendor_id, references(:vendor, on_delete: :nilify_all)
   end
  end
end
