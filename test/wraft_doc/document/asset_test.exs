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

  @font_style_name ~w(Regular Italic Bold BoldItalic)

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

    # FIXME Need to fix this issues with format naming
    test "returns invalid changeset with invalid data", %{asset: asset} do
      changeset = Asset.file_changeset(asset, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset, :file)
    end

    test "returns valid changeset for valid theme file" do
      for font_style <- @font_style_name do
        theme_file = %Plug.Upload{
          filename: "Roboto-#{font_style}.ttf",
          content_type: "font/ttf",
          path: File.cwd!() <> "/priv/wraft_files/Roboto/Roboto-#{font_style}.ttf"
        }

        asset = insert(:asset, name: "Bold", type: "theme")
        changeset = Asset.file_changeset(asset, %{file: theme_file})
        assert changeset.valid?
      end
    end

    # FIXME Need to fix this
    test "returns error for invalid theme file type" do
      theme_file = %Plug.Upload{
        filename: "letterhead.pdf",
        content_type: "application/pdf",
        path: File.cwd!() <> "/priv/wraft_files/letterhead.pdf"
      }

      asset = insert(:asset, name: "Bold", type: "theme")
      changeset = Asset.file_changeset(asset, %{file: theme_file})
      refute changeset.valid?
      assert "invalid file type" in errors_on(changeset, :file)
    end

    # FIXME Need to fix this
    test "returns error for invalid format for theme file name" do
      theme_file = %Plug.Upload{
        filename: "roboto.ttf",
        content_type: "font/ttf",
        path: File.cwd!() <> "/test/helper/roboto.ttf"
      }

      asset = insert(:asset, name: "Bold", type: "theme")
      changeset = Asset.file_changeset(asset, %{file: theme_file})
      refute changeset.valid?
      assert "invalid file type" in errors_on(changeset, :file)
    end
  end
end
