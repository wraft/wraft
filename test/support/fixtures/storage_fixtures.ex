defmodule WraftDoc.StorageFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WraftDoc.Storage` context.
  """

  @doc """
  Generate a repository.
  """
  def repository_fixture(attrs \\ %{}) do
    user = WraftDoc.Factory.insert(:user)
    organisation = WraftDoc.Factory.insert(:organisation)

    {:ok, repository} =
      attrs
      |> Enum.into(%{
        current_storage_used: 42,
        description: "some description",
        item_count: 42,
        name: "some name",
        status: "some status",
        storage_limit: 42,
        creator_id: user.id,
        organisation_id: organisation.id
      })
      |> WraftDoc.Storages.create_repository()

    repository
  end

  @doc """
  Generate a storage_asset.
  """
  def storage_asset_fixture(attrs \\ %{}) do
    WraftDoc.Factory.insert(:storage_asset, attrs)
  end

  @doc """
  Generate a storage_item.
  """
  def storage_item_fixture(attrs \\ %{}) do
    WraftDoc.Factory.insert(:storage_item, attrs)
  end

  @doc """
  Generate a sync_job.
  """
  def sync_job_fixture(attrs \\ %{}) do
    WraftDoc.Factory.insert(:sync_job, attrs)
  end
end
