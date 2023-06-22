defmodule WraftDoc.Document.AssetTest do
  use WraftDoc.ModelCase, async: true
  @moduletag :document
  import WraftDoc.Factory

  alias WraftDoc.Document.Asset

  @valid_attrs %{name: "asset one", type: "layout", organisation_id: Faker.UUID.v4()}

  @file_attrs %{
    file: %Plug.Upload{
      filename: "invoice.pdf",
      content_type: "application/pdf",
      path: "test/helper/invoice.pdf"
    }
  }

  @valid_update_attrs Map.merge(%{name: "asset one"}, @file_attrs)

  @invalid_attrs %{name: nil, type: nil, organisation_id: nil, file: nil}

  describe "changeset/2" do
    test "returns valid changeset with valid data" do
      changeset = Asset.changeset(%Asset{}, @valid_attrs)
      assert changeset.valid?
    end

    test "returns invalid changeset with invalid attributes" do
      changeset = Asset.changeset(%Asset{}, @invalid_attrs)
      refute changeset.valid?

      for key <- Map.keys(@valid_attrs) do
        assert "can't be blank" in errors_on(changeset, key)
      end
    end

    test "only theme and layout values are allowed for type field" do
      for type <- ["layout", "theme"] do
        changeset = Asset.changeset(%Asset{}, Map.put(@valid_attrs, :type, type))
        assert changeset.valid?
      end

      changeset = Asset.changeset(%Asset{}, Map.put(@valid_attrs, :type, "new_type"))
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset, :type)
    end
  end

  setup do
    [asset: insert(:asset)]
  end

  describe "update_changeset/2" do
    test "returns valid changeset with valid data", %{asset: asset} do
      changeset = Asset.update_changeset(asset, @valid_update_attrs)
      assert changeset.valid?
    end

    test "returns invalid changeset with invalid attributes", %{asset: asset} do
      changeset = Asset.update_changeset(asset, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset, :name)
      assert "can't be blank" in errors_on(changeset, :file)
      assert [] == errors_on(changeset, :type)
      assert [] == errors_on(changeset, :organisation_id)
    end
  end

  describe "file_changeset/2" do
    test "returns valid changeset with valid data", %{asset: asset} do
      changeset = Asset.file_changeset(asset, @file_attrs)
      assert changeset.valid?
    end

    test "returns invalid changeset with invalid data", %{asset: asset} do
      changeset = Asset.file_changeset(asset, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset, :file)
    end
  end
end
