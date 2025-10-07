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
      |> WraftDoc.Storage.create_repository()

    repository
  end

  @doc """
  Generate a storage_item using Factory.
  """
  def storage_item_fixture(attrs \\ %{}) do
    user = WraftDoc.Factory.insert(:user)
    organisation = WraftDoc.Factory.insert(:organisation)
    repository = repository_fixture()

    WraftDoc.Factory.insert(
      :storage_item,
      Map.merge(
        %{
          name: "some name",
          mime_type: "some mime_type",
          creator_id: user.id,
          organisation_id: organisation.id,
          repository_id: repository.id
        },
        attrs
      )
    )
  end
end
