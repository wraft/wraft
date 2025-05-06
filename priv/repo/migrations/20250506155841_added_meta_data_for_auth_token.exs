defmodule WraftDoc.Repo.Migrations.AddedMetaDataForAuthToken do
  use Ecto.Migration

  def change do
    alter table(:auth_token) do
      add(:meta_data, :map)
    end
  end
end
