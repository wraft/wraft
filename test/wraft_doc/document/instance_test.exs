defmodule WraftDoc.Document.InstanceTest do
  use WraftDoc.ModelCase
  alias WraftDoc.{Document.Instance, Repo}
  import WraftDoc.Factory
  @moduletag :document
  @valid_attrs %{
    instance_id: "OFFL01",
    raw: "Content",
    serialized: %{title: "Title of the content", body: "Body of the content"},
    type: 1
  }
  @invalid_attrs %{raw: ""}

  test "changeset with valid attributes" do
    content_type = insert(:content_type)
    state = insert(:state)
    params = Map.merge(@valid_attrs, %{content_type_id: content_type.id, state_id: state.id})
    changeset = Instance.changeset(%Instance{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
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
    state = insert(:state)
    content_type = insert(:content_type)
    params = Map.merge(@valid_attrs, %{content_type_id: content_type.id, state_id: state.id})

    {:ok, _instance} = %Instance{} |> Instance.changeset(params) |> Repo.insert()
    {:error, changeset} = %Instance{} |> Instance.changeset(params) |> Repo.insert()

    assert "Instance with the ID exists.!" in errors_on(changeset, :instance_id)
  end

  test "types/0 returns a list" do
    types = Instance.types()
    assert types == [normal: 1, bulk_build: 2, pipeline_api: 3, pipeline_hook: 4]
  end

  # TOOD tests for unique constraint in update_changeset
  # TODO tests for update_state_changeset
  # TODO tests for lock_modify_changeset
end
