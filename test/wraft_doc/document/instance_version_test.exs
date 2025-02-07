defmodule WraftDoc.Document.Instance.VersionTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Instance.Version
  import WraftDoc.Factory
  @moduletag :document

  @valid_attrs %{
    version_number: "save:0,build:1",
    type: :build,
    naration: "sample naration",
    raw: "sample raw data",
    serialized: %{body: "sample raw data"},
    content_id: "b1b67eb3-a8c7-4492-beb5-c8d6ad3abbef"
  }

  @invalid_attrs %{version_number: "v1"}

  test "changeset with valid attributes" do
    user = insert(:user)
    params = Map.put(@valid_attrs, :author_id, user.id)
    changeset = Version.changeset(%Version{}, params)
    assert changeset.valid?
  end

  test "valid changeset with invalid attributes" do
    changeset = Version.changeset(%Version{}, @invalid_attrs)
    refute changeset.valid?
  end
end
