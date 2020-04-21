defmodule WraftDoc.InstanceVersionTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.Instance.Version
  import Ecto

  @valid_attrs %{
    version_number: 1,
    raw: "sample raw data",
    serialized: %{body: "sample raw data"}
  }
  @invalid_attrs %{version_number: "v1"}

  test "changeset with valid attributes" do
    changeset = Version.changeset(%Version{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Version.changeset(%Version{}, @invalid_attrs)
    refute changeset.valid?
  end
end
