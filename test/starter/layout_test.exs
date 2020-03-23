defmodule WraftDoc.LayoutTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Layout
  import WraftDoc.Factory

  @valid_attrs %{
    name: "Official Letter",
    description: "An official letter",
    width: 40.0,
    height: 20.0,
    unit: "cm",
    slug: "Pandoc",
    slug_file: "/official_letter.zip",
    screenshot: "/official_letter.jpg",
    organisation_id: 12
  }
  @update_invalid_attrs %{
    name: "Official Letter",
    description: "An official letter",
    width: 40.0,
    height: 20.0,
    unit: "cm",
    slug: "Pandoc",
    organisation_id: 12
  }

  @invalid_attrs %{name: "Official Letter", description: "An official letter", width: 40.0}

  test "changeset with valid attrs" do
    changeset = Layout.changeset(%Layout{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = Layout.changeset(%Layout{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "update changeset with valid attrs" do
    engine = insert(:engine)
    valid_attrs = Map.put(@valid_attrs, :engine_id, engine.id)
    changeset = Layout.update_changeset(%Layout{}, valid_attrs)
    assert changeset.valid?
  end

  test "update changeset with invalid attrs" do
    changeset = Layout.update_changeset(%Layout{}, @update_invalid_attrs)
    refute changeset.valid?
  end

  test "layout name unique constraint" do
    organisation = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation.id)

    {:ok, _layout} = Layout.changeset(%Layout{}, params) |> Repo.insert()
    {:error, changeset} = Layout.changeset(%Layout{}, params) |> Repo.insert()
    assert "Layout with the same name exists. Use another name.!" in errors_on(changeset, :name)
  end
end
