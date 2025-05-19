defmodule WraftDoc.CloudService.CloudServiceAssets do
  @moduledoc """
  Context for managing Google Drive file metadata.
  """

  import Ecto.Query, warn: false
  alias WraftDoc.CloudService.CloudServiceAsset
  alias WraftDoc.Repo

  @doc """
  Creates a Cloud Service Asset.
  """
  def create_cloud_service_assets(attrs \\ %{}) do
    %CloudServiceAsset{}
    |> CloudServiceAsset.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Cloud Service Asset.
  """
  def update_cloud_service_assets(%CloudServiceAsset{} = file, attrs) do
    file
    |> CloudServiceAsset.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Cloud Service Asset.
  """
  def delete_cloud_service_assets(%CloudServiceAsset{} = file) do
    Repo.delete(file)
  end
end
