defmodule WraftDoc.VendorsTest do
  use WraftDoc.DataCase, async: false

  import Mox

  alias WraftDoc.Repo
  alias WraftDoc.Vendors
  alias WraftDoc.Vendors.Vendor
  alias WraftDoc.Vendors.VendorContact

  setup :verify_on_exit!

  @valid_vendor_attrs %{
    "name" => "vendor name",
    "email" => "vendor@example.com",
    "phone" => "555-0123",
    "address" => "123 Main Street",
    "city" => "Sample City",
    "country" => "Sample Country",
    "website" => "https://vendor.example.com",
    "reg_no" => "REG12345678",
    "contact_person" => "vendor contact_person"
  }
  @invalid_vendor_attrs %{"name" => nil}

  @valid_vendor_contact_attrs %{
    "name" => "John Smith",
    "email" => "john.smith@vendor.com",
    "phone" => "555-0199",
    "job_title" => "Sales Manager"
  }
  @invalid_vendor_contact_attrs %{"name" => nil, "vendor_id" => nil}

  describe "create_vendor/2" do
    test "create vendor on valid attributes" do
      user = insert(:user_with_organisation)
      count_before = Vendor |> Repo.all() |> length()
      vendor = WraftDoc.Vendors.create_vendor(user, @valid_vendor_attrs)
      assert count_before + 1 == Vendor |> Repo.all() |> length()
      assert vendor.name == @valid_vendor_attrs["name"]
      assert vendor.email == @valid_vendor_attrs["email"]
      assert vendor.phone == @valid_vendor_attrs["phone"]
      assert vendor.address == @valid_vendor_attrs["address"]
      assert vendor.reg_no == @valid_vendor_attrs["reg_no"]

      assert vendor.contact_person == @valid_vendor_attrs["contact_person"]
      assert vendor.city == @valid_vendor_attrs["city"]
      assert vendor.country == @valid_vendor_attrs["country"]
      assert vendor.website == @valid_vendor_attrs["website"]
    end

    test "create vendor on invalid attrs" do
      user = insert(:user_with_organisation)
      count_before = Vendor |> Repo.all() |> length()

      {:error, changeset} = WraftDoc.Vendors.create_vendor(user, @invalid_vendor_attrs)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before == count_after

      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "update_vendor/2" do
    test "update vendor on valid attrs" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      count_before = Vendor |> Repo.all() |> length()

      attrs =
        Map.merge(@valid_vendor_attrs, %{
          "organisation_id" => List.first(user.owned_organisations).id,
          "creator_id" => user.id
        })

      vendor = WraftDoc.Vendors.update_vendor(vendor, attrs)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before == count_after
      assert vendor.name == @valid_vendor_attrs["name"]
      assert vendor.email == @valid_vendor_attrs["email"]
      assert vendor.phone == @valid_vendor_attrs["phone"]
      assert vendor.address == @valid_vendor_attrs["address"]
      assert vendor.reg_no == @valid_vendor_attrs["reg_no"]
    end

    test "returns error on invalid attrs" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      count_before = Vendor |> Repo.all() |> length()

      {:error, changeset} = WraftDoc.Vendors.update_vendor(vendor, @invalid_vendor_attrs)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before == count_after
      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "get_vendor/1" do
    test "get vendor returns the vendor data" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      v_vendor = WraftDoc.Vendors.get_vendor(user, vendor.id)
      assert v_vendor.name == vendor.name
      assert v_vendor.email == vendor.email
      assert v_vendor.phone == vendor.phone
      assert v_vendor.address == vendor.address
      assert v_vendor.reg_no == vendor.reg_no

      assert v_vendor.contact_person == vendor.contact_person
    end

    test "get vendor from another organisation will not be possible" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user)
      v_vendor = WraftDoc.Vendors.get_vendor(user, vendor.id)
      assert v_vendor == {:error, :invalid_id, "Vendor"}
    end
  end

  describe "show vendor" do
    test "show vendor returns the vendor data and preloads" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      v_vendor = WraftDoc.Vendors.show_vendor(vendor.id, user)
      assert v_vendor.name == vendor.name
      assert v_vendor.email == vendor.email
      assert v_vendor.phone == vendor.phone
      assert v_vendor.address == vendor.address
      assert v_vendor.reg_no == vendor.reg_no

      assert v_vendor.contact_person == vendor.contact_person
    end
  end

  describe "delete_vendor/1" do
    test "delete vendor deletes the vendor data" do
      vendor = insert(:vendor)
      count_before = Vendor |> Repo.all() |> length()
      {:ok, v_vendor} = WraftDoc.Vendors.delete_vendor(vendor)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before - 1 == count_after
      assert v_vendor.name == vendor.name
      assert v_vendor.email == vendor.email
      assert v_vendor.phone == vendor.phone
      assert v_vendor.address == vendor.address
      assert v_vendor.reg_no == vendor.reg_no

      assert v_vendor.contact_person == vendor.contact_person
    end
  end

  test "vendor index lists the vendor data" do
    user = insert(:user_with_organisation)
    [organisation] = user.owned_organisations
    v1 = insert(:vendor, creator: user, organisation: organisation)
    v2 = insert(:vendor, creator: user, organisation: organisation)
    vendor_index = WraftDoc.Vendors.vendor_index(user, %{page_number: 1})

    assert vendor_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ v1.name
    assert vendor_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ v2.name
  end

  # ===============================
  # VENDOR CONTACT TESTS
  # ===============================

  describe "create_vendor_contact/2" do
    test "create vendor contact on valid attributes" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      count_before = VendorContact |> Repo.all() |> length()

      contact_attrs = Map.put(@valid_vendor_contact_attrs, "vendor_id", vendor.id)
      vendor_contact = WraftDoc.Vendors.create_vendor_contact(user, contact_attrs)

      assert count_before + 1 == VendorContact |> Repo.all() |> length()
      assert vendor_contact.name == @valid_vendor_contact_attrs["name"]
      assert vendor_contact.email == @valid_vendor_contact_attrs["email"]
      assert vendor_contact.phone == @valid_vendor_contact_attrs["phone"]
      assert vendor_contact.job_title == @valid_vendor_contact_attrs["job_title"]
      assert vendor_contact.vendor_id == vendor.id
    end

    test "create vendor contact on invalid attrs" do
      user = insert(:user_with_organisation)
      count_before = VendorContact |> Repo.all() |> length()

      {:error, changeset} =
        WraftDoc.Vendors.create_vendor_contact(user, @invalid_vendor_contact_attrs)

      count_after = VendorContact |> Repo.all() |> length()
      assert count_before == count_after

      assert %{name: ["can't be blank"], vendor_id: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "get_vendor_contact/2" do
    test "get vendor contact by id" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      contact = insert(:vendor_contact, vendor: vendor, creator: user)

      retrieved_contact = WraftDoc.Vendors.get_vendor_contact(user, contact.id)
      assert retrieved_contact.id == contact.id
      assert retrieved_contact.name == contact.name
    end

    test "returns error for invalid id" do
      user = insert(:user_with_organisation)
      result = WraftDoc.Vendors.get_vendor_contact(user, Ecto.UUID.generate())
      assert result == {:error, :invalid_id}
    end

    test "returns error for contact from different organisation" do
      user1 = insert(:user_with_organisation)
      user2 = insert(:user_with_organisation)

      vendor =
        insert(:vendor, creator: user2, organisation: List.first(user2.owned_organisations))

      contact = insert(:vendor_contact, vendor: vendor, creator: user2)

      result = WraftDoc.Vendors.get_vendor_contact(user1, contact.id)
      assert result == {:error, :invalid_id}
    end
  end

  describe "update_vendor_contact/2" do
    test "update vendor contact on valid attrs" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      contact = insert(:vendor_contact, vendor: vendor, creator: user)
      count_before = VendorContact |> Repo.all() |> length()

      {:ok, updated_contact} =
        WraftDoc.Vendors.update_vendor_contact(contact, @valid_vendor_contact_attrs)

      count_after = VendorContact |> Repo.all() |> length()

      assert count_before == count_after
      assert updated_contact.name == @valid_vendor_contact_attrs["name"]
      assert updated_contact.email == @valid_vendor_contact_attrs["email"]
      assert updated_contact.phone == @valid_vendor_contact_attrs["phone"]
      assert updated_contact.job_title == @valid_vendor_contact_attrs["job_title"]
    end

    test "returns error on invalid attrs" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      contact = insert(:vendor_contact, vendor: vendor, creator: user)
      count_before = VendorContact |> Repo.all() |> length()

      {:error, changeset} =
        WraftDoc.Vendors.update_vendor_contact(contact, @invalid_vendor_contact_attrs)

      count_after = VendorContact |> Repo.all() |> length()

      assert count_before == count_after
      assert %{name: ["can't be blank"], vendor_id: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "delete_vendor_contact/1" do
    test "delete vendor contact" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
      contact = insert(:vendor_contact, vendor: vendor, creator: user)
      count_before = VendorContact |> Repo.all() |> length()

      {:ok, deleted_contact} = WraftDoc.Vendors.delete_vendor_contact(contact)
      count_after = VendorContact |> Repo.all() |> length()

      assert count_before - 1 == count_after
      assert deleted_contact.id == contact.id
    end
  end

  describe "vendor_contacts_index/3" do
    test "list vendor contacts with pagination" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))

      contact1 = insert(:vendor_contact, vendor: vendor, creator: user)
      contact2 = insert(:vendor_contact, vendor: vendor, creator: user)

      # Create contact for different vendor to ensure filtering
      other_vendor =
        insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))

      _other_contact = insert(:vendor_contact, vendor: other_vendor, creator: user)

      result = WraftDoc.Vendors.vendor_contacts_index(user, vendor.id, %{page_number: 1})

      contact_ids = Enum.map(result.entries, & &1.id)
      assert contact1.id in contact_ids
      assert contact2.id in contact_ids
      assert length(result.entries) == 2
    end

    test "returns empty list for vendor with no contacts" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))

      result = WraftDoc.Vendors.vendor_contacts_index(user, vendor.id, %{page_number: 1})

      assert result.entries == []
      assert result.total_entries == 0
    end
  end

  describe "get_vendor_stats/1" do
    setup do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      vendor = insert(:vendor, creator: user, organisation: organisation)

      %{user: user, organisation: organisation, vendor: vendor}
    end

    test "returns correct stats for vendor with no documents", %{vendor: vendor} do
      stats = Vendors.get_vendor_stats(vendor)

      assert stats.total_documents == 0
      assert stats.pending_approvals == 0
      assert stats.total_contract_value == Decimal.new(0)
      assert stats.total_contacts == 0
      assert stats.new_this_month == 0
    end

    test "returns correct total_documents count", %{
      user: user,
      organisation: organisation,
      vendor: vendor
    } do
      # Create some documents associated with the vendor
      content_type = insert(:content_type, organisation: organisation)
      insert(:instance, content_type: content_type, vendor: vendor, creator: user)
      insert(:instance, content_type: content_type, vendor: vendor, creator: user)
      insert(:instance, content_type: content_type, vendor: vendor, creator: user)

      # Create a document for a different vendor to ensure it's not counted
      other_vendor = insert(:vendor, creator: user, organisation: organisation)
      insert(:instance, content_type: content_type, vendor: other_vendor, creator: user)

      stats = Vendors.get_vendor_stats(vendor)

      assert stats.total_documents == 3
    end

    test "returns correct pending_approvals count", %{
      user: user,
      organisation: organisation,
      vendor: vendor
    } do
      content_type = insert(:content_type, organisation: organisation)

      # Create documents with different approval statuses
      insert(:instance,
        content_type: content_type,
        vendor: vendor,
        creator: user,
        approval_status: false
      )

      insert(:instance,
        content_type: content_type,
        vendor: vendor,
        creator: user,
        approval_status: false
      )

      insert(:instance,
        content_type: content_type,
        vendor: vendor,
        creator: user,
        approval_status: true
      )

      stats = Vendors.get_vendor_stats(vendor)

      assert stats.pending_approvals == 2
    end

    test "returns correct total_contacts count", %{user: user, vendor: vendor} do
      # Create vendor contacts
      insert(:vendor_contact, vendor: vendor, creator: user)
      insert(:vendor_contact, vendor: vendor, creator: user)
      insert(:vendor_contact, vendor: vendor, creator: user)

      # Create contact for different vendor to ensure it's not counted
      other_vendor = insert(:vendor, creator: user, organisation: vendor.organisation)
      insert(:vendor_contact, vendor: other_vendor, creator: user)

      stats = Vendors.get_vendor_stats(vendor)

      assert stats.total_contacts == 3
    end

    test "returns correct new_this_month count for current month documents", %{
      user: user,
      organisation: organisation,
      vendor: vendor
    } do
      content_type = insert(:content_type, organisation: organisation)

      # Create documents (they will be created with current timestamp, which is this month)
      insert(:instance, content_type: content_type, vendor: vendor, creator: user)
      insert(:instance, content_type: content_type, vendor: vendor, creator: user)
      insert(:instance, content_type: content_type, vendor: vendor, creator: user)

      stats = Vendors.get_vendor_stats(vendor)

      # All documents created today should count as "new this month"
      assert stats.new_this_month == 3
    end

    test "returns comprehensive stats with mixed data", %{
      user: user,
      organisation: organisation,
      vendor: vendor
    } do
      content_type = insert(:content_type, organisation: organisation)

      # Create vendor contacts
      insert(:vendor_contact, vendor: vendor, creator: user)
      insert(:vendor_contact, vendor: vendor, creator: user)

      # Create documents with various properties
      insert(:instance,
        content_type: content_type,
        vendor: vendor,
        creator: user,
        approval_status: false
      )

      insert(:instance,
        content_type: content_type,
        vendor: vendor,
        creator: user,
        approval_status: true
      )

      insert(:instance,
        content_type: content_type,
        vendor: vendor,
        creator: user,
        approval_status: false
      )

      stats = Vendors.get_vendor_stats(vendor)

      assert stats.total_documents == 3
      assert stats.pending_approvals == 2
      assert stats.total_contacts == 2
      # new_this_month will be 3 since all documents are created today (this month)
      assert stats.new_this_month == 3
      # total_contract_value will be 0 since no contract values are set
      assert Decimal.equal?(stats.total_contract_value, Decimal.new(0))
    end

    test "handles vendor gracefully and returns proper map structure", %{vendor: vendor} do
      # This test ensures the function works without errors and returns expected structure
      stats = Vendors.get_vendor_stats(vendor)

      # Should return map with all required keys
      assert is_map(stats)
      assert Map.has_key?(stats, :total_documents)
      assert Map.has_key?(stats, :pending_approvals)
      assert Map.has_key?(stats, :total_contract_value)
      assert Map.has_key?(stats, :total_contacts)
      assert Map.has_key?(stats, :new_this_month)

      # All values should be numbers or Decimal
      assert is_integer(stats.total_documents)
      assert is_integer(stats.pending_approvals)
      assert is_integer(stats.total_contacts)
      assert is_integer(stats.new_this_month)
      assert %Decimal{} = stats.total_contract_value
    end

    test "returns zero values for vendor with no associated data", %{vendor: vendor} do
      # Don't create any documents, contacts, etc.
      stats = Vendors.get_vendor_stats(vendor)

      assert stats.total_documents == 0
      assert stats.pending_approvals == 0
      assert stats.total_contract_value == Decimal.new(0)
      assert stats.total_contacts == 0
      assert stats.new_this_month == 0
    end
  end
end
