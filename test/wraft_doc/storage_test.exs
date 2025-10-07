defmodule WraftDoc.StorageTest do
  use WraftDoc.DataCase

  alias WraftDoc.Storage

  describe "repositories" do
    alias WraftDoc.Storage.Repository

    import WraftDoc.StorageFixtures

    @invalid_attrs %{
      name: nil,
      status: nil,
      description: nil,
      storage_limit: nil,
      current_storage_used: nil,
      item_count: nil
    }

    test "list_repositories/0 returns all repositories" do
      repository = repository_fixture()
      repositories = Storage.list_repositories()
      assert repository in repositories
    end

    test "get_repository!/1 returns the repository with given id" do
      repository = repository_fixture()
      assert Storage.get_repository!(repository.id) == repository
    end

    test "create_repository/1 with valid data creates a repository" do
      user = WraftDoc.Factory.insert(:user)
      organisation = WraftDoc.Factory.insert(:organisation)

      valid_attrs = %{
        name: "some name",
        status: "some status",
        description: "some description",
        storage_limit: 42,
        current_storage_used: 42,
        item_count: 42,
        creator_id: user.id,
        organisation_id: organisation.id
      }

      assert {:ok, %Repository{} = repository} = Storage.create_repository(valid_attrs)
      assert repository.name == "some name"
      assert repository.status == "some status"
      assert repository.description == "some description"
      assert repository.storage_limit == 42
      assert repository.current_storage_used == 42
      assert repository.item_count == 42
    end

    test "create_repository/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Storage.create_repository(@invalid_attrs)
    end

    test "update_repository/2 with valid data updates the repository" do
      repository = repository_fixture()

      update_attrs = %{
        name: "some updated name",
        status: "some updated status",
        description: "some updated description",
        storage_limit: 43,
        current_storage_used: 43,
        item_count: 43
      }

      assert {:ok, %Repository{} = repository} =
               Storage.update_repository(repository, update_attrs)

      assert repository.name == "some updated name"
      assert repository.status == "some updated status"
      assert repository.description == "some updated description"
      assert repository.storage_limit == 43
      assert repository.current_storage_used == 43
      assert repository.item_count == 43
    end

    test "update_repository/2 with invalid data returns error changeset" do
      repository = repository_fixture()
      assert {:error, %Ecto.Changeset{}} = Storage.update_repository(repository, @invalid_attrs)
      assert repository == Storage.get_repository!(repository.id)
    end

    test "delete_repository/1 deletes the repository" do
      repository = repository_fixture()
      assert {:ok, %Repository{}} = Storage.delete_repository(repository)
      assert_raise Ecto.NoResultsError, fn -> Storage.get_repository!(repository.id) end
    end

    test "change_repository/1 returns a repository changeset" do
      repository = repository_fixture()
      assert %Ecto.Changeset{} = Storage.change_repository(repository)
    end
  end
end
