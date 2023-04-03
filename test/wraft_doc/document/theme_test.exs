defmodule WraftDoc.Document.ThemeTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.Theme
  @moduletag :document
  @valid_attrs %{
    name: "Official Letter Theme",
    font: "Malery",
    typescale: %{h1: "10", p: "6", h2: "8"},
    file: "/malory.css",
    organisation_id: 12
  }

  @invalid_attrs %{
    name: "Official Letter Theme",
    font: "Malery"
  }

  test "changeset with valid attributes" do
    organisation = insert(:organisation)
    valid_attrs = Map.put(@valid_attrs, :organisation_id, organisation.id)
    changeset = Theme.changeset(%Theme{}, valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Theme.changeset(%Theme{}, @invalid_attrs)
    refute changeset.valid?
  end

  # TODO include tests for validate_format for changeset & update_changeset
  # TODO include tests for file_changeset
end
