defmodule WraftDoc.Document.InstanceTest do
  use WraftDoc.ModelCase
  alias WraftDoc.{Document.Instance, Repo}
  import WraftDoc.Factory

  @valid_attrs %{
    instance_id: "OFFL01",
    raw: "Content",
    serialized: %{title: "Title of the content", body: "Body of the content"},
    type: 1
  }
  @invalid_attrs %{raw: ""}

  test "changeset with valid attributes" do
    content_type = insert(:content_type)
    params = Map.put(@valid_attrs, :content_type_id, content_type.id)
    changeset = Instance.changeset(%Instance{}, params)
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
    changeset = Instance.update_changeset(%Instance{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "instance id unique constraint" do
    %{id: id} = insert(:content_type)
    params = Map.put(@valid_attrs, :content_type_id, id)

    {:ok, _instance} = %Instance{} |> Instance.changeset(params) |> Repo.insert()
    {:error, changeset} = %Instance{} |> Instance.changeset(params) |> Repo.insert()

    assert "Instance with the ID exists.!" in errors_on(changeset, :instance_id)
  end

  test "types/0 returns a list" do
    types = Instance.types()
    assert types == [normal: 1, bulk_build: 2, pipeline_api: 3, pipeline_hook: 4]
  end
end
