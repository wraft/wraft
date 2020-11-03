defmodule WraftDoc.Enterprise.VendorTest do
  use WraftDoc.ModelCase
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
    user = insert(:user)

    params =
      @valid_attrs
      |> Map.merge(%{"organisation_id" => user.organisation.id, "creator_id" => user.id})

    changeset = Vendor.changeset(%Vendor{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid data" do
    changeset = Vendor.changeset(%Vendor{}, @invalid_attrs)
    refute changeset.valid?
  end
end
