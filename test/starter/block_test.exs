defmodule WraftDoc.BlockTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.{Document, Document.Block, Repo}
  require IEx
  @invalid_attrs %{name: "Block name"}
  test "changest with valid attributes" do
    organisation = insert(:organisation)
    content_type = insert(:content_type)

    valid_attrs = %{
      name: "Address",
      btype: "string",
      organisation_id: organisation.id,
      content_type_id: content_type.id
    }

    changeset = Block.changeset(%Block{}, valid_attrs)

    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = Block.changeset(%Block{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "block name unique index" do
    # block = insert(:block, name: "block name")

    organisation = insert(:organisation)
    content_type = insert(:content_type)

    params = %{
      name: "block name",
      btype: "string",
      organisation_id: organisation.id,
      content_type_id: content_type.id
    }

    {:ok, block} = Block.changeset(%Block{}, params) |> Repo.insert()
    {:error, changeset} = Block.changeset(%Block{}, params) |> Repo.insert()

    assert "Block with same name exists.!" in errors_on(changeset, :name)
  end
end
