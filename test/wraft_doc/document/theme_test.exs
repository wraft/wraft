defmodule WraftDoc.Document.ThemeTest do
  use WraftDoc.ModelCase

  alias WraftDoc.Document.Theme

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
    changeset = Theme.changeset(%Theme{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Theme.changeset(%Theme{}, @invalid_attrs)
    refute changeset.valid?
  end
end
