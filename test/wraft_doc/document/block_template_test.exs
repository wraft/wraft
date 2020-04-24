defmodule WraftDoc.Document.BlockTemplateTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.BlockTemplate

  @valid_attrs %{
    title: "a sample title",
    body: "a sample body",
    serialised: "a sample serialised"
  }
  @invalid_attrs %{title: "", body: "", serialised: ""}

  test "changeset with valid data" do
    organisation = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation.id)
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
