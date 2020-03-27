defmodule WraftDoc.AssetTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.Asset

  @create_attrs %{name: "asset one"}
  @invalid_attrs %{}

  test "changeset with valid data" do
    organisation = insert(:organisation)
    params = Map.put(@create_attrs, :organisation_id, organisation.id)
    changeset = Asset.changeset(%Asset{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Asset.changeset(%Asset{}, @invalid_attrs)
    refute changeset.valid?
  end
end
