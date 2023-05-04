defmodule WraftDoc.Enterprise.VendorTest do
  use WraftDoc.ModelCase
  @moduletag :enterprise
  import WraftDoc.Factory

  alias WraftDoc.Enterprise.Vendor

  @valid_attrs %{
    "name" => "vendor name",
    "email" => "vendor email",
    "phone" => "vendor phone",
    "address" => "vendor address",
    "gstin" => "vendor gstin",
    "reg_no" => "vendor reg_no",
    "contact_person" => "vendor contact_person"
  }
  @invalid_attrs %{}
  test "changeset with valid data " do
    %{id: user_id, owned_organisations: [organisation]} = insert(:user_with_organisation)

    params =
      Map.merge(@valid_attrs, %{
        "organisation_id" => organisation.id,
        "creator_id" => user_id
      })

    changeset = Vendor.changeset(%Vendor{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid data" do
    changeset = Vendor.changeset(%Vendor{}, @invalid_attrs)
    refute changeset.valid?
  end

  # TODO test for update_changeset
  # TOOD test for cast_attachment in update_changeset
end
