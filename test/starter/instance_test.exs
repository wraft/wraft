defmodule WraftDoc.InstanceTest do
  use WraftDoc.ModelCase
  alias WraftDoc.{Document.Instance, Repo}
  import WraftDoc.Factory

  @valid_attrs %{
    instance_id: "OFFL01",
    raw: "Content",
    serialized: %{title: "Title of the content", body: "Body of the content"}
  }
  @update_invalid_attrs %{
    instance_id: "OFFL01",
    raw: "Content",
    serialized: %{title: "Title of the content", body: "Body of the content"}
  }

  @invalid_attrs %{}
  test "changeset with valid attributes" do
    changeset = Instance.changeset(%Instance{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with in valid attributes" do
    changeset = Instance.changeset(%Instance{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "update changeset with valid attrs" do
    state = insert(:state)
    valid_attrs = Map.put(@valid_attrs, :state_id, state.id)
    changeset = Instance.update_changeset(%Instance{}, valid_attrs)
    assert changeset.valid?
  end

  test "update changeset with invalid attrs" do
    changeset = Instance.update_changeset(%Instance{}, @update_invalid_attrs)
    refute changeset.valid?
  end

  test "instance id unique constraint" do
    {:ok, instance} = Instance.changeset(%Instance{}, @valid_attrs) |> Repo.insert()
    IO.inspect(instance.instance_id)
    {:ok, instance} = Instance.changeset(%Instance{}, @valid_attrs) |> Repo.insert()
    IO.inspect(instance.instance_id)
    {:error, changeset} = Instance.changeset(%Instance{}, @valid_attrs) |> Repo.insert()
    assert "Instance with the ID exists.!" in errors_on(changeset, :instance_id)
  end
end
