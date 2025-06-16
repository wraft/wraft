defmodule WraftDoc.CloudImport.CloudImportAssets do
  @moduledoc """
  Context for managing Google Drive file metadata.
  """

  import Ecto.Query, warn: false
  alias WraftDoc.CloudImport.CloudImportAsset
  alias WraftDoc.Repo

  @doc """
  Creates a Cloud Service Asset.
  """
  def create_cloud_service_assets(attrs \\ %{}) do
    %CloudImportAsset{}
    |> CloudImportAsset.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Cloud Service Asset.
  """
  def update_cloud_service_assets(%CloudImportAsset{} = file, attrs) do
    file
    |> CloudImportAsset.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Cloud Service Asset.
  """
  def delete_cloud_service_assets(%CloudImportAsset{} = file) do
    Repo.delete(file)
  end
end
