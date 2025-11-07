defmodule WraftDoc.Storages.StorageAssets do
  @moduledoc """
  Context module for managing storage assets, repositories, access logs, and sync jobs.

  This module provides functions for managing file uploads, querying assets,
  scheduling asset deletions, and handling storage asset lifecycle operations.
  Storage assets represent files stored in various backends (local, S3, MinIO, etc.)
  with associated metadata like checksums, file sizes, and processing status.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias WraftDoc.Repo
  alias WraftDoc.Storages.StorageAsset
  alias WraftDoc.Workers.StorageAssetDeletionWorker

  @type storage_asset_attrs :: map()
  @type storage_asset_result :: {:ok, StorageAsset.t()} | {:error, Ecto.Changeset.t()}
  @type file_metadata :: %{
          storage_key: String.t(),
          file_size: integer(),
          checksum_sha256: String.t(),
          mime_type: String.t()
        }
  @type user :: %{id: integer()} | nil
  @type organisation_id :: integer()
  @type storage_item_id :: integer()

  @doc """
  Returns the list of all storage assets.

  ## Examples

      iex> list_storage_assets()
      [%StorageAsset{}, ...]

  """
  @spec list_storage_assets() :: [StorageAsset.t()]
  def list_storage_assets, do: Repo.all(StorageAsset)

  @doc """
  Gets a single storage asset by ID.

  Raises `Ecto.NoResultsError` if the storage asset does not exist.

  ## Examples

      iex> get_storage_asset!(123)
      %StorageAsset{}

      iex> get_storage_asset!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_storage_asset!(integer()) :: StorageAsset.t()
  def get_storage_asset!(id), do: Repo.get!(StorageAsset, id)

  @doc """
  Creates a storage asset with the given attributes.

  ## Examples

      iex> create_storage_asset(%{filename: "test.pdf", storage_key: "key123"})
      {:ok, %StorageAsset{}}

      iex> create_storage_asset(%{filename: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_storage_asset(storage_asset_attrs()) :: storage_asset_result()
  def create_storage_asset(attrs \\ %{}) do
    %StorageAsset{}
    |> StorageAsset.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a storage asset with the given attributes in a multi.
  """
  @spec create_storage_asset_multi(storage_asset_attrs()) :: storage_asset_result()
  def create_storage_asset_multi(params) do
    Multi.new()
    |> Multi.insert(:storage_asset, fn _ ->
      StorageAsset.changeset(%StorageAsset{}, params)
    end)
    |> Multi.update(:upload_file, fn %{storage_asset: storage_asset} ->
      storage_asset
      |> Repo.preload(:storage_item)
      |> StorageAsset.file_changeset(params)
    end)
    |> Multi.update(:complete_upload, fn %{upload_file: storage_asset} ->
      StorageAsset.changeset(storage_asset, %{
        processing_status: "completed",
        upload_completed_at: DateTime.utc_now()
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{complete_upload: storage_asset}} ->
        {:ok, storage_asset}

      {:error, _, reason, _} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a storage asset with the given attributes.

  ## Examples

      iex> update_storage_asset(storage_asset, %{processing_status: "completed"})
      {:ok, %StorageAsset{}}

      iex> update_storage_asset(storage_asset, %{filename: nil})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_storage_asset(StorageAsset.t(), storage_asset_attrs()) :: storage_asset_result()
  def update_storage_asset(%StorageAsset{} = storage_asset, attrs) do
    storage_asset
    |> StorageAsset.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a storage asset.

  ## Examples

      iex> delete_storage_asset(storage_asset)
      {:ok, %StorageAsset{}}

      iex> delete_storage_asset(storage_asset)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_storage_asset(StorageAsset.t()) :: storage_asset_result()
  def delete_storage_asset(%StorageAsset{} = storage_asset), do: Repo.delete(storage_asset)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking storage asset changes.

  ## Examples

      iex> change_storage_asset(storage_asset)
      %Ecto.Changeset{data: %StorageAsset{}}

  """
  @spec change_storage_asset(StorageAsset.t(), storage_asset_attrs()) :: Ecto.Changeset.t()
  def change_storage_asset(%StorageAsset{} = storage_asset, attrs \\ %{}),
    do: StorageAsset.changeset(storage_asset, attrs)

  @doc """
  Gets a storage asset by ID and organisation ID.

  Returns the storage asset if it exists and belongs to the specified organisation,
  otherwise returns `nil`.

  ## Examples

      iex> get_storage_asset_by_org(123, 456)
      %StorageAsset{}

      iex> get_storage_asset_by_org(999, 456)
      nil

  """
  @spec get_storage_asset_by_org(integer(), organisation_id()) :: StorageAsset.t() | nil
  def get_storage_asset_by_org(id, organisation_id) do
    StorageAsset
    |> where([s], s.id == ^id and s.organisation_id == ^organisation_id)
    |> Repo.one()
  end

  @doc """
  Lists all storage assets for a given organisation.

  Returns assets ordered by insertion date (newest first).

  ## Examples

      iex> list_storage_assets_by_organisation(123)
      [%StorageAsset{}, ...]

      iex> list_storage_assets_by_organisation(999)
      []

  """
  @spec list_storage_assets_by_organisation(organisation_id()) :: [StorageAsset.t()]
  def list_storage_assets_by_organisation(organisation_id) do
    StorageAsset
    |> where([s], s.organisation_id == ^organisation_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets all storage assets for a specific storage item.

  Returns assets ordered by insertion date (newest first).

  ## Examples

      iex> get_storage_assets_for_item(789)
      [%StorageAsset{}, ...]

      iex> get_storage_assets_for_item(999)
      []

  """
  @spec get_storage_assets_for_item(storage_item_id()) :: [StorageAsset.t()]
  def get_storage_assets_for_item(storage_item_id) do
    StorageAsset
    |> where([sa], sa.storage_item_id == ^storage_item_id)
    |> order_by([sa], desc: sa.inserted_at)
    |> Repo.all()
    |> Repo.preload(:storage_item)
  end

  @doc """
  Builds parameters for storage asset creation from file metadata and upload info.

  Creates a parameter map suitable for creating a new storage asset with all
  necessary metadata including file information, storage backend, and user context.

  ## Parameters

    * `params` - Additional parameters (currently unused)
    * `file_metadata` - Map containing file metadata (storage_key, file_size, etc.)
    * `upload` - Upload filename
    * `current_user` - User performing the upload (can be nil)
    * `organisation_id` - ID of the organisation owning the asset

  ## Examples

      iex> build_storage_asset_params(%{}, file_metadata, "test.pdf", user)
      {:ok, %{filename: "test.pdf", storage_key: "key123", ...}}

  """
  @spec build_storage_asset_params(
          file_metadata(),
          String.t(),
          User.t()
        ) :: {:ok, storage_asset_attrs()}
  def build_storage_asset_params(
        file_metadata,
        file_upload,
        %{current_org_id: organisation_id} = current_user
      ) do
    storage_asset_params = %{
      filename: file_upload,
      storage_key: file_metadata.storage_key,
      # TODO: Make configurable - could be "s3", "minio" based on config
      storage_backend: "local",
      file_size: file_metadata.file_size,
      checksum_sha256: file_metadata.checksum_sha256,
      mime_type: file_metadata.mime_type,
      processing_status: "pending",
      upload_completed_at: nil,
      creator_id: current_user && current_user.id,
      organisation_id: organisation_id
    }

    {:ok, storage_asset_params}
  end

  @doc """
  Schedules an asset deletion job for the given storage item.

  Creates and enqueues a background job to delete all assets associated
  with the specified storage item ID.

  ## Examples

      iex> schedule_asset_deletion(123)
      {:ok, %Oban.Job{}}

      iex> schedule_asset_deletion(invalid_id)
      {:error, reason}

  """
  @spec schedule_asset_deletion(storage_item_id()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def schedule_asset_deletion(storage_item_id) do
    job = StorageAssetDeletionWorker.new(%{storage_item_id: storage_item_id})
    Oban.insert(job)
  end
end
