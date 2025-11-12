defmodule WraftDoc.Storages.StorageAsset do
  @moduledoc """
  The sync job model.
  """
  use Waffle.Ecto.Schema
  use WraftDoc.Schema

  @foreign_key_type :binary_id

  schema "storage_assets" do
    field(:filename, WraftDocWeb.StorageAssetUploader.Type)
    field(:storage_key, :string)
    field(:storage_backend, :string)
    field(:file_size, :integer)
    field(:checksum_sha256, :string)
    field(:mime_type, :string)
    field(:encryption_key_id, :string)
    field(:compression_type, :string)
    field(:thumbnail_path, :string)
    field(:preview_path, :string)
    field(:processing_status, :string)
    field(:upload_completed_at, :utc_datetime)
    belongs_to(:storage_item, WraftDoc.Storages.StorageItem)

    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  @doc """
  Standard changeset for storage asset creation and updates.
  """
  def changeset(storage_asset, attrs) do
    storage_asset
    |> cast(attrs, [
      :storage_key,
      :storage_backend,
      :file_size,
      :checksum_sha256,
      :mime_type,
      :encryption_key_id,
      :compression_type,
      :thumbnail_path,
      :preview_path,
      :processing_status,
      :upload_completed_at,
      :storage_item_id,
      :creator_id,
      :organisation_id
    ])
    |> validate_required([
      :storage_key,
      :storage_backend,
      :file_size,
      :mime_type,
      :processing_status
    ])
    |> validate_inclusion(:storage_backend, ["local", "s3", "minio", "gcs"])
    |> validate_inclusion(:processing_status, ["pending", "processing", "completed", "failed"])
    |> validate_number(:file_size, greater_than: 0)
    |> foreign_key_constraint(:storage_item_id)
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:organisation_id)
  end

  @doc """
  File upload changeset that handles Waffle file attachments.
  """
  def file_changeset(storage_asset, attrs) do
    storage_asset
    |> cast_attachments(attrs, [:filename])
    |> validate_required([:filename])
  end

  @doc """
  Public changeset for storage assets created without user authentication.
  """
  def public_changeset(storage_asset, attrs) do
    storage_asset
    |> cast(attrs, [
      :storage_key,
      :storage_backend,
      :file_size,
      :checksum_sha256,
      :mime_type,
      :encryption_key_id,
      :compression_type,
      :thumbnail_path,
      :preview_path,
      :processing_status,
      :upload_completed_at,
      :storage_item_id,
      :organisation_id
    ])
    |> validate_required([
      :storage_key,
      :storage_backend,
      :file_size,
      :mime_type,
      :processing_status
    ])
    |> validate_inclusion(:storage_backend, ["local", "s3", "minio", "gcs"])
    |> validate_inclusion(:processing_status, ["pending", "processing", "completed", "failed"])
    |> validate_number(:file_size, greater_than: 0)
    |> foreign_key_constraint(:storage_item_id)
    |> foreign_key_constraint(:organisation_id)
  end

  @doc """
  Update changeset for modifying existing storage assets.
  """
  def update_changeset(storage_asset, attrs) do
    storage_asset
    |> cast(attrs, [
      :processing_status,
      :upload_completed_at,
      :thumbnail_path,
      :preview_path,
      :encryption_key_id,
      :compression_type
    ])
    |> validate_inclusion(:processing_status, ["pending", "processing", "completed", "failed"])
  end
end
