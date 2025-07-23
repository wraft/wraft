defmodule WraftDocWeb.Api.V1.VendorControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.Repo
  alias WraftDoc.Vendors.Vendor
  alias WraftDoc.Vendors.VendorContact

  @valid_attrs %{
    name: "a sample Name",
    email: "vendor@example.com",
    phone: "555-0123",
    address: "123 Main Street",
    city: "Sample City",
    country: "Sample Country",
    website: "https://example.com",
    gstin: "GST1234567890",
    reg_no: "REG12345678",
    contact_person: "John Doe"
  }

  @valid_contact_attrs %{
    name: "John Smith",
    email: "john.smith@vendor.com",
    phone: "555-0199",
    job_title: "Sales Manager"
  }

  @invalid_contact_attrs %{name: nil, vendor_id: nil}

  describe "create/2" do
    test "create vendors by valid attrrs", %{conn: conn} do
      count_before = Vendor |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_vendor_path(conn, :create), @valid_attrs)
        |> doc(operation_id: "create_resource")

      assert count_before + 1 == Vendor |> Repo.all() |> length()
      assert json_response(conn, 200)["email"] == @valid_attrs.email
    end

    test "does not create vendors by invalid attrs", %{conn: conn} do
      count_before = Vendor |> Repo.all() |> length()

      invalid_attrs_with_email = %{name: nil, email: "invalid-email"}

      conn =
        conn
        |> post(Routes.v1_vendor_path(conn, :create), invalid_attrs_with_email)
        |> doc(operation_id: "create_resource")

      response = json_response(conn, 422)
      assert response["errors"]["name"] == ["can't be blank"]
      assert response["errors"]["email"] == ["must be a valid email address"]
      assert count_before == Vendor |> Repo.all() |> length()
    end
  end

  describe "update/2" do
    test "update vendors on valid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      vendor = insert(:vendor, organisation: organisation, creator: user)

      count_before = Vendor |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_vendor_path(conn, :update, vendor.id, @valid_attrs))
        |> doc(operation_id: "update_resource")

      assert json_response(conn, 200)["email"] == @valid_attrs.email
      assert count_before == Vendor |> Repo.all() |> length()
    end

    test "does't update vendors for invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)

      invalid_attrs_with_email = %{name: nil, email: "invalid-email"}

      conn =
        conn
        |> put(Routes.v1_vendor_path(conn, :update, vendor.id, invalid_attrs_with_email))
        |> doc(operation_id: "update_resource")

      response = json_response(conn, 422)
      assert response["errors"]["name"] == ["can't be blank"]
      assert response["errors"]["email"] == ["must be a valid email address"]
    end
  end

  describe "index/2" do
    test "index lists vendor by current user", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations

      a1 = insert(:vendor, organisation: organisation, creator: user)
      a2 = insert(:vendor, organisation: organisation, creator: user)

      conn = get(conn, Routes.v1_vendor_path(conn, :index))
      vendor_index = json_response(conn, 200)["vendors"]
      vendors = Enum.map(vendor_index, fn %{"email" => email} -> email end)
      assert List.to_string(vendors) =~ a1.email
      assert List.to_string(vendors) =~ a2.email
    end
  end

  describe "show/2" do
    test "show renders vendor details by id", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)

      conn = get(conn, Routes.v1_vendor_path(conn, :show, vendor.id))

      assert json_response(conn, 200)["name"] == vendor.name
    end

    test "error not found for id does not exists", %{conn: conn} do
      conn = get(conn, Routes.v1_vendor_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 400)["errors"] == "The Vendor id does not exist..!"
    end
  end

  describe "delete" do
    test "delete vendor by given id", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)
      count_before = Vendor |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_vendor_path(conn, :delete, vendor.id))
      assert count_before - 1 == Vendor |> Repo.all() |> length()
      assert json_response(conn, 200)["email"] == vendor.email
    end
  end

  describe "create_contact/2" do
    test "creates vendor contact with valid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)
      count_before = VendorContact |> Repo.all() |> length()

      contact_attrs = Map.put(@valid_contact_attrs, :vendor_id, vendor.id)

      conn =
        conn
        |> post(Routes.v1_vendor_path(conn, :create_contact, vendor.id), contact_attrs)
        |> doc(operation_id: "create_vendor_contact")

      assert count_before + 1 == VendorContact |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == @valid_contact_attrs.name
      assert json_response(conn, 200)["email"] == @valid_contact_attrs.email
    end

    test "does not create vendor contact with invalid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)
      count_before = VendorContact |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_vendor_path(conn, :create_contact, vendor.id), @invalid_contact_attrs)
        |> doc(operation_id: "create_vendor_contact")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
      assert count_before == VendorContact |> Repo.all() |> length()
    end
  end

  describe "contacts_index/2" do
    test "lists vendor contacts with pagination", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)

      contact1 = insert(:vendor_contact, vendor: vendor, creator: user)
      contact2 = insert(:vendor_contact, vendor: vendor, creator: user)

      conn = get(conn, Routes.v1_vendor_path(conn, :contacts_index, vendor.id))

      response = json_response(conn, 200)
      contact_names = Enum.map(response["contacts"], fn %{"name" => name} -> name end)

      assert contact1.name in contact_names
      assert contact2.name in contact_names
      assert response["page_number"] == 1
    end
  end

  describe "show_contact/2" do
    test "shows vendor contact details", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)
      contact = insert(:vendor_contact, vendor: vendor, creator: user)

      conn = get(conn, Routes.v1_vendor_path(conn, :show_contact, vendor.id, contact.id))

      assert json_response(conn, 200)["name"] == contact.name
      assert json_response(conn, 200)["email"] == contact.email
    end

    test "returns error for non-existent contact", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)

      conn =
        get(conn, Routes.v1_vendor_path(conn, :show_contact, vendor.id, Ecto.UUID.generate()))

      assert json_response(conn, 400)["errors"] == "The id does not exist..!"
    end
  end

  describe "update_contact/2" do
    test "updates vendor contact with valid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)
      contact = insert(:vendor_contact, vendor: vendor, creator: user)
      count_before = VendorContact |> Repo.all() |> length()

      conn =
        conn
        |> put(
          Routes.v1_vendor_path(conn, :update_contact, vendor.id, contact.id),
          @valid_contact_attrs
        )
        |> doc(operation_id: "update_vendor_contact")

      assert json_response(conn, 200)["name"] == @valid_contact_attrs.name
      assert count_before == VendorContact |> Repo.all() |> length()
    end

    test "does not update vendor contact with invalid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)
      contact = insert(:vendor_contact, vendor: vendor, creator: user)

      conn =
        conn
        |> put(
          Routes.v1_vendor_path(conn, :update_contact, vendor.id, contact.id),
          @invalid_contact_attrs
        )
        |> doc(operation_id: "update_vendor_contact")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "delete_contact/2" do
    test "deletes vendor contact by given id", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: List.first(user.owned_organisations), creator: user)
      contact = insert(:vendor_contact, vendor: vendor, creator: user)
      count_before = VendorContact |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_vendor_path(conn, :delete_contact, vendor.id, contact.id))

      assert count_before - 1 == VendorContact |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == contact.name
    end
  end
end

describe "vendor stats" do
  setup [:create_user_and_organisation, :create_vendor]

  test "returns vendor stats successfully", %{conn: conn, vendor: vendor} do
    conn = get(conn, Routes.vendor_path(conn, :stats, vendor.id))

    assert %{
             "total_documents" => 0,
             "pending_approvals" => 0,
             "total_contract_value" => _,
             "total_contacts" => 0,
             "new_this_month" => 0
           } = json_response(conn, 200)
  end

  test "returns vendor stats with documents", %{
    conn: conn,
    vendor: vendor,
    user: user,
    organisation: organisation
  } do
    # Create some test data
    content_type = insert(:content_type, organisation: organisation)
    insert(:instance, content_type: content_type, vendor: vendor, creator: user)

    insert(:instance,
      content_type: content_type,
      vendor: vendor,
      creator: user,
      approval_status: false
    )

    insert(:vendor_contact, vendor: vendor, creator: user)

    conn = get(conn, Routes.vendor_path(conn, :stats, vendor.id))

    response = json_response(conn, 200)

    assert response["total_documents"] == 2
    assert response["pending_approvals"] == 1
    assert response["total_contacts"] == 1
    assert response["new_this_month"] == 2
    assert Map.has_key?(response, "total_contract_value")
  end

  test "returns 404 for non-existent vendor", %{conn: conn} do
    conn = get(conn, Routes.vendor_path(conn, :stats, Ecto.UUID.generate()))
    assert json_response(conn, 404)
  end

  test "returns 404 for vendor from different organisation", %{conn: conn} do
    other_user = insert(:user_with_organisation)
    [other_organisation] = other_user.owned_organisations
    other_vendor = insert(:vendor, creator: other_user, organisation: other_organisation)

    conn = get(conn, Routes.vendor_path(conn, :stats, other_vendor.id))
    assert json_response(conn, 404)
  end

  test "returns stats with proper data types", %{conn: conn, vendor: vendor} do
    conn = get(conn, Routes.vendor_path(conn, :stats, vendor.id))
    response = json_response(conn, 200)

    # Verify all required fields are present and have correct types
    assert is_integer(response["total_documents"])
    assert is_integer(response["pending_approvals"])
    assert is_integer(response["total_contacts"])
    assert is_integer(response["new_this_month"])
    # total_contract_value should be a string representation of decimal
    assert is_binary(response["total_contract_value"]) or
             is_number(response["total_contract_value"])
  end
end
