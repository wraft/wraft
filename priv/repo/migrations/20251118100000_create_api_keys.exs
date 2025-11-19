defmodule WraftDoc.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:key_hash, :string, null: false)
      add(:key_prefix, :string, null: false)
      
      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all),
        null: false
      )
      
      add(:user_id, references(:user, type: :uuid, on_delete: :delete_all), null: false)
      
      add(:created_by_id, references(:user, type: :uuid, on_delete: :nilify_all))
      
      # Security settings
      add(:expires_at, :utc_datetime)
      add(:is_active, :boolean, default: true, null: false)
      add(:rate_limit, :integer, default: 1000)
      add(:ip_whitelist, {:array, :string}, default: [])
      
      # Usage tracking
      add(:last_used_at, :utc_datetime)
      add(:usage_count, :integer, default: 0, null: false)
      
      # Additional metadata
      add(:metadata, :map, default: %{})
      
      timestamps()
    end

    create(index(:api_keys, [:organisation_id]))
    create(index(:api_keys, [:user_id]))
    create(index(:api_keys, [:is_active]))
    create(index(:api_keys, [:expires_at]))
    create(index(:api_keys, [:key_prefix]))
    create(unique_index(:api_keys, [:key_hash]))
    create(unique_index(:api_keys, [:name, :organisation_id]))
  end
end

