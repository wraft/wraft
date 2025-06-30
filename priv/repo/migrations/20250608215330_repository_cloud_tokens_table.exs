defmodule WraftDoc.Repo.Migrations.RepositoryCloudTokensTable do
  use Ecto.Migration

  def change do
    create table(:repository_cloud_tokens) do
      add(:access_token, :string)
      add(:refresh_token, :string)
      add(:expires_at, :utc_datetime)
      add(:provider, :string)
      add(:meta_data, :map, default: %{})
      add(:external_user_data, :map, default: %{})
      add(:user_id, references(:user, type: :uuid, on_delete: :delete_all))

      timestamps()
    end
  end
end
