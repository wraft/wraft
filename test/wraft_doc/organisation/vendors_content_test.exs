defmodule WraftDoc.Enterprise.VendorsContentTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory

  alias WraftDoc.Enterprise.VendorsContent
  alias WraftDoc.Repo

  describe "changeset/2" do
    setup do
      user = insert(:user_with_organisation)
      organisation = hd(user.owned_organisations)
      vendor = insert(:vendor, creator: user, organisation: organisation)
      content_type = insert(:content_type, creator: user, organisation: organisation)

      content =
        insert(:instance, creator: user, content_type: content_type, organisation: organisation)

      %{
        vendor: vendor,
        content: content,
        valid_attrs: %{vendor_id: vendor.id, content_id: content.id}
      }
    end

    test "with valid attributes", %{valid_attrs: valid_attrs} do
      changeset = VendorsContent.changeset(%VendorsContent{}, valid_attrs)
      assert changeset.valid?
    end

    test "is invalid without vendor_id", %{valid_attrs: valid_attrs} do
      attrs = Map.delete(valid_attrs, :vendor_id)
      changeset = VendorsContent.changeset(%VendorsContent{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).vendor_id == ["can't be blank"]
    end

    test "is invalid without content_id", %{valid_attrs: valid_attrs} do
      attrs = Map.delete(valid_attrs, :content_id)
      changeset = VendorsContent.changeset(%VendorsContent{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).content_id == ["can't be blank"]
    end

    test "is invalid with non-existent vendor_id", %{valid_attrs: valid_attrs} do
      # Using a non-existent integer ID.
      non_existent_vendor_id = -1
      attrs = Map.put(valid_attrs, :vendor_id, non_existent_vendor_id)
      changeset = VendorsContent.changeset(%VendorsContent{}, attrs)

      {:error, error_changeset} = Repo.insert(changeset)
      assert errors_on(error_changeset).vendor_id == ["Please enter a valid vendor"]
    end

    test "is invalid with non-existent content_id", %{valid_attrs: valid_attrs} do
      non_existent_content_id = -1
      attrs = Map.put(valid_attrs, :content_id, non_existent_content_id)
      changeset = VendorsContent.changeset(%VendorsContent{}, attrs)

      {:error, error_changeset} = Repo.insert(changeset)
      assert errors_on(error_changeset).content_id == ["Please enter a valid content"]
    end

    test "is invalid if combination of vendor_id and content_id is not unique", %{
      valid_attrs: valid_attrs
    } do
      # First, insert a valid record.
      {:ok, _} = Repo.insert(VendorsContent.changeset(%VendorsContent{}, valid_attrs))

      # Then, try to insert the same combination again.
      changeset = VendorsContent.changeset(%VendorsContent{}, valid_attrs)
      {:error, error_changeset} = Repo.insert(changeset)

      assert errors_on(error_changeset).vendor_id == ["already exist"]
    end
  end
end
