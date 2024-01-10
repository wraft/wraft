defmodule WraftDoc.Authorization.PermissionTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory

  alias WraftDoc.Authorization.Permission

  @valid_attrs %{name: "test_permission:test", resource: "test", action: "test"}
  @invalid_attrs %{name: nil, resource: nil, action: nil}

  describe "changeset/2" do
    test "returns valid changeset with valid changeset" do
      changeset = Permission.changeset(%Permission{}, @valid_attrs)
      assert changeset.valid?
    end

    test "returns invalid changeset with invalid changeset" do
      changeset = Permission.changeset(%Permission{}, @invalid_attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :name)
      assert "can't be blank" in errors_on(changeset, :action)
      assert "can't be blank" in errors_on(changeset, :resource)
    end

    test "checks unique constraint on name" do
      insert(:permission, name: "test_permission:test")
      {:error, changeset} = %Permission{} |> Permission.changeset(@valid_attrs) |> Repo.insert()

      refute changeset.valid?
      assert "permission already exist" in errors_on(changeset, :name)
    end

    test "checks unique constraint on resource-action combination" do
      insert(:permission, action: "test", resource: "test")
      {:error, changeset} = %Permission{} |> Permission.changeset(@valid_attrs) |> Repo.insert()

      refute changeset.valid?

      assert "combination of resource and action has to be unique" in errors_on(
               changeset,
               :resource
             )
    end
  end
end
