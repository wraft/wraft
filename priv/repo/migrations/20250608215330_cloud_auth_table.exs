defmodule WraftDoc.Repo.Migrations.CloudAuthTable do
  use Ecto.Migration

  def change do
    create table(:cloud_auth_tokens) do
      add(:access_token, :string)
      add(:refresh_token, :string)
      add(:expires_at, :utc_datetime)
      add(:service, :string)
      add(:meta_data, :map, default: %{})
      add(:external_user_data, :map, default: %{})
      add(:user_id, references(:user, type: :uuid, on_delete: :delete_all))

      timestamps()
    end
  end
end
