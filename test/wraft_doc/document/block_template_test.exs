defmodule WraftDoc.Document.BlockTemplateTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.BlockTemplates.BlockTemplate
  @moduletag :document
  @valid_attrs %{
    title: "a sample title",
    body: "a sample body",
    serialized: "a sample serialized"
  }
  @invalid_attrs %{title: "", body: "", serialized: ""}

  # TODO include tests for unique constraints

  test "changeset with valid data" do
    organisation = insert(:organisation)
    user = insert(:user)
    params = Map.merge(@valid_attrs, %{organisation_id: organisation.id, creator_id: user.id})
    changeset = BlockTemplate.changeset(%BlockTemplate{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = BlockTemplate.changeset(%BlockTemplate{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "update changeset with valid data" do
    block_template = insert(:block_template)
    changeset = BlockTemplate.update_changeset(block_template, @valid_attrs)
    assert changeset.valid?
  end

  test "update changeset with invalid data" do
    block_template = insert(:block_template)
    changeset = BlockTemplate.update_changeset(block_template, @invalid_attrs)
    refute changeset.valid?
  end
end
