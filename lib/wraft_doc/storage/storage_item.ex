defmodule WraftDoc.Storage.StorageItem do
  @moduledoc """
  The sync job model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storage_items" do
    field(:name, :string)
    field(:size, :integer)
    field(:path, :string)
    field(:metadata, :map)
    field(:display_name, :string)
    field(:item_type, :string)
    field(:path_hash, :string)
    field(:depth_level, :integer)
    field(:materialized_path, :string)
    field(:mime_type, :string)
    field(:file_extension, :string)
    field(:checksum_sha256, :string)
    field(:version_number, :string)
    field(:is_current_version, :boolean, default: false)
    field(:classification_level, :string)
    field(:is_deleted, :boolean, default: false)
    field(:deleted_at, :utc_datetime)
    field(:sync_source, :string)
    field(:external_id, :string)
    field(:external_metadata, :map)
    field(:last_synced_at, :utc_datetime)
    field(:content_extracted, :boolean, default: false)
    field(:thumbnail_generated, :boolean, default: false)
    field(:download_count, :integer)
    field(:last_accessed_at, :utc_datetime)
    field(:parent_id, :binary_id)

    has_many(:storage_assets, WraftDoc.Storage.StorageAsset)
    belongs_to(:repository, WraftDoc.Storage.Repository)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  @doc false
  def changeset(storage_item, attrs) do
    storage_item
    |> cast(attrs, [
      :name,
      :display_name,
      :item_type,
      :path,
      :path_hash,
      :depth_level,
      :materialized_path,
      :mime_type,
      :file_extension,
      :size,
      :checksum_sha256,
      :version_number,
      :is_current_version,
      :classification_level,
      :is_deleted,
      :deleted_at,
      :sync_source,
      :external_id,
      :external_metadata,
      :last_synced_at,
      :content_extracted,
      :thumbnail_generated,
      :download_count,
      :last_accessed_at,
      :metadata,
      :parent_id,
      :repository_id,
      :creator_id,
      :organisation_id
    ])
    # :path, :materialized_path, :mime_type])
    |> validate_required([:name, :mime_type])
    |> unique_constraint([:external_id, :sync_source],
      name: :storage_items_external_id_sync_source_index
    )
  end
end
