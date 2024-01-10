defmodule WraftDoc.Document.BlockTest do
  use WraftDoc.ModelCase
  @moduletag :document
  import WraftDoc.Factory
  alias WraftDoc.{Document.Block, Repo}

  @invalid_attrs %{name: "Block name"}

  # TODO include tests for cast attachments
  test "changest with valid attributes" do
    organisation = insert(:organisation)
    user = insert(:user)

    valid_attrs = %{
      name: "Address",
      file_url: "www.example.com/block.pdf",
      dataset: %{title: "title1"},
      creator_id: user.id,
      organisation_id: organisation.id
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
    user = insert(:user)

    params = %{
      name: "block name",
      btype: "string",
      file_url: "www.example.com/block.pdf",
      dataset: %{title: "title1"},
      organisation_id: organisation.id,
      creator_id: user.id
    }

    {:ok, _block} = %Block{} |> Block.changeset(params) |> Repo.insert()
    {:error, changeset} = %Block{} |> Block.changeset(params) |> Repo.insert()

    assert "Block with same name exists.!" in errors_on(changeset, :name)
  end
end
