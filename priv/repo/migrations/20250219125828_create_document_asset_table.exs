defmodule WraftDoc.Repo.Migrations.CreateDocumentAssetTable do
  use Ecto.Migration

  def change do
    create table(:document_assets, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:document_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
