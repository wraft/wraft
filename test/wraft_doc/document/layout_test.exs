defmodule WraftDoc.Document.LayoutTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Layout
  import WraftDoc.Factory
  @moduletag :document
  @valid_attrs %{
    name: "Official Letter",
    description: "An official letter",
    width: 40.0,
    height: 20.0,
    unit: "cm",
    slug: "Pandoc",
    slug_file: "/official_letter.zip",
    screenshot: "/official_letter.jpg"
  }
  @update_invalid_attrs %{
    name: "Official Letter",
    description: "An official letter",
    width: 40.0,
    height: 20.0,
    unit: "cm",
    slug: "Pandoc"
  }

  @invalid_attrs %{name: "Official Letter", description: "An official letter", width: 40.0}

  test "changeset with valid attrs" do
    organisation = insert(:organisation)
    engine = insert(:engine)

    valid_attrs =
      Map.merge(@valid_attrs, %{organisation_id: organisation.id, engine_id: engine.id})

    changeset = Layout.changeset(%Layout{}, valid_attrs)
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

  @tag :individual
  test "layout name unique constraint" do
    organisation = insert(:organisation)
    layout = insert(:layout)
    engine = insert(:engine)

    params =
      Map.merge(@valid_attrs, %{
        organisation_id: organisation.id,
        name: layout.name,
        engine_id: engine.id
      })

    %Layout{} |> Layout.changeset(params) |> Repo.insert()
    {:error, changeset} = %Layout{} |> Layout.changeset(params) |> Repo.insert()

    assert "Layout with the same name exists. Use another name.!" in errors_on(changeset, :name)
  end

  # TODO update changeset unique constraint
  # TODO tests for file_changeset
end
