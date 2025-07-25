defmodule WraftDoc.Vendors.VendorContactTest do
  use WraftDoc.ModelCase
  @moduletag :vendors
  import WraftDoc.Factory

  alias WraftDoc.Vendors.VendorContact

  @valid_attrs %{
    "name" => "John Smith",
    "email" => "john.smith@vendor.com",
    "phone" => "555-0199",
    "job_title" => "Sales Manager"
  }

  @invalid_attrs %{
    "name" => nil,
    "email" => "invalid-email",
    "phone" => nil,
    "job_title" => nil
  }

  describe "changeset/2" do
    test "changeset with valid data" do
      vendor = insert(:vendor)
      user = insert(:user)

      params =
        Map.merge(@valid_attrs, %{
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      assert changeset.valid?
    end

    test "changeset with invalid data" do
      changeset = VendorContact.changeset(%VendorContact{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset requires name" do
      vendor = insert(:vendor)
      user = insert(:user)

      params =
        Map.merge(@valid_attrs, %{
          "name" => nil,
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :name)
    end

    test "changeset requires vendor_id" do
      user = insert(:user)

      params =
        Map.merge(@valid_attrs, %{
          "vendor_id" => nil,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :vendor_id)
    end

    test "changeset validates email format" do
      vendor = insert(:vendor)
      user = insert(:user)

      params =
        Map.merge(@valid_attrs, %{
          "email" => "invalid-email",
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      refute changeset.valid?
      assert "must be a valid email address" in errors_on(changeset, :email)
    end

    test "changeset validates email length" do
      vendor = insert(:vendor)
      user = insert(:user)
      long_email = String.duplicate("a", 250) <> "@example.com"

      params =
        Map.merge(@valid_attrs, %{
          "email" => long_email,
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset, :email)
    end

    test "changeset validates phone length" do
      vendor = insert(:vendor)
      user = insert(:user)
      long_phone = String.duplicate("1", 51)

      params =
        Map.merge(@valid_attrs, %{
          "phone" => long_phone,
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      refute changeset.valid?
      assert "should be at most 50 character(s)" in errors_on(changeset, :phone)
    end

    test "changeset validates job_title length" do
      vendor = insert(:vendor)
      user = insert(:user)
      long_job_title = String.duplicate("a", 101)

      params =
        Map.merge(@valid_attrs, %{
          "job_title" => long_job_title,
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset, :job_title)
    end

    test "changeset validates name length" do
      vendor = insert(:vendor)
      user = insert(:user)

      # Test minimum length
      params_short =
        Map.merge(@valid_attrs, %{
          "name" => "a",
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset_short = VendorContact.changeset(%VendorContact{}, params_short)
      refute changeset_short.valid?
      assert "should be at least 2 character(s)" in errors_on(changeset_short, :name)

      # Test maximum length
      long_name = String.duplicate("a", 256)

      params_long =
        Map.merge(@valid_attrs, %{
          "name" => long_name,
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset_long = VendorContact.changeset(%VendorContact{}, params_long)
      refute changeset_long.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset_long, :name)
    end

    test "changeset allows optional fields to be nil" do
      vendor = insert(:vendor)
      user = insert(:user)

      params = %{
        "name" => "John Smith",
        "email" => nil,
        "phone" => nil,
        "job_title" => nil,
        "vendor_id" => vendor.id,
        "creator_id" => user.id
      }

      changeset = VendorContact.changeset(%VendorContact{}, params)
      assert changeset.valid?
    end

    test "changeset allows valid email to be nil" do
      vendor = insert(:vendor)
      user = insert(:user)

      params =
        Map.merge(@valid_attrs, %{
          "email" => nil,
          "vendor_id" => vendor.id,
          "creator_id" => user.id
        })

      changeset = VendorContact.changeset(%VendorContact{}, params)
      assert changeset.valid?
    end
  end
end
