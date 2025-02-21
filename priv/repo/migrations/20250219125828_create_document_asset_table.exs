defmodule WraftDoc.Repo.Migrations.CreateDocumentAssetTable do
  use Ecto.Migration

  def change do
    alter table(:asset) do
      add(:expiry_date, :utc_datetime)
      add(:url, :text)
    end
  end
end
