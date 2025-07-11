defmodule WraftDocWeb.Api.V1.VendorControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.Enterprise.Vendor
  alias WraftDoc.Enterprise.VendorContact
  alias WraftDoc.Repo

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
      contact_names = Enum.map(response["vendor_contacts"], fn %{"name" => name} -> name end)

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

  describe "connect_to_document" do
    setup [:create_user_and_vendor, :create_document_instance]

    test "connects vendor to document successfully", %{
      conn: conn,
      vendor: vendor,
      instance: instance
    } do
      conn =
        put(
          conn,
          "/api/v1/contents/#{instance.id}/vendors/#{vendor.id}"
        )

      response = json_response(conn, 200)
      assert response["instance"]["id"] == instance.id
      assert response["vendor"]["id"] == vendor.id
      assert response["vendor"]["name"] == vendor.name

      # Verify the database was updated
      updated_instance = Repo.get(WraftDoc.Documents.Instance, instance.id)
      assert updated_instance.vendor_id == vendor.id
    end

    test "returns error when vendor does not exist", %{
      conn: conn,
      instance: instance
    } do
      non_existent_vendor_id = Ecto.UUID.generate()

      conn =
        put(
          conn,
          "/api/v1/contents/#{instance.id}/vendors/#{non_existent_vendor_id}"
        )

      assert json_response(conn, 400)
    end

    test "returns error when document does not exist", %{
      conn: conn,
      vendor: vendor
    } do
      non_existent_document_id = Ecto.UUID.generate()

      conn =
        put(
          conn,
          "/api/v1/contents/#{non_existent_document_id}/vendors/#{vendor.id}"
        )

      assert json_response(conn, 400)
    end

    test "returns error when vendor belongs to different organisation", %{
      conn: conn,
      instance: instance
    } do
      other_user = insert(:user_with_organisation)

      other_vendor =
        insert(:vendor,
          creator: other_user,
          organisation: List.first(other_user.owned_organisations)
        )

      conn =
        put(
          conn,
          "/api/v1/contents/#{instance.id}/vendors/#{other_vendor.id}"
        )

      assert json_response(conn, 400)
    end

    test "returns error when document belongs to different organisation", %{
      conn: conn,
      vendor: vendor
    } do
      other_user = insert(:user_with_organisation)

      other_content_type =
        insert(:content_type,
          creator: other_user,
          organisation: List.first(other_user.owned_organisations)
        )

      other_instance = insert(:instance, creator: other_user, content_type: other_content_type)

      conn =
        put(
          conn,
          "/api/v1/contents/#{other_instance.id}/vendors/#{vendor.id}"
        )

      assert json_response(conn, 400)
    end
  end

  describe "disconnect_from_document" do
    setup [:create_user_and_vendor, :create_document_instance_with_vendor]

    test "disconnects vendor from document successfully", %{
      conn: conn,
      vendor: vendor,
      instance: instance
    } do
      # Verify the vendor is initially connected
      assert instance.vendor_id == vendor.id

      conn =
        delete(
          conn,
          "/api/v1/contents/#{instance.id}/vendors/#{vendor.id}"
        )

      response = json_response(conn, 200)
      assert response["instance"]["id"] == instance.id
      assert response["vendor"] == nil

      # Verify the database was updated
      updated_instance = Repo.get(WraftDoc.Documents.Instance, instance.id)
      assert updated_instance.vendor_id == nil
    end

    test "returns error when vendor does not exist", %{
      conn: conn,
      instance: instance
    } do
      non_existent_vendor_id = Ecto.UUID.generate()

      conn =
        delete(
          conn,
          "/api/v1/contents/#{instance.id}/vendors/#{non_existent_vendor_id}"
        )

      assert json_response(conn, 400)
    end

    test "returns error when document does not exist", %{
      conn: conn,
      vendor: vendor
    } do
      non_existent_document_id = Ecto.UUID.generate()

      conn =
        delete(
          conn,
          "/api/v1/contents/#{non_existent_document_id}/vendors/#{vendor.id}"
        )

      assert json_response(conn, 400)
    end

    test "successfully disconnects even when document has no vendor", %{
      conn: conn,
      vendor: vendor
    } do
      # Create a document without a vendor
      user = conn.assigns.current_user
      organisation = List.first(user.owned_organisations)
      content_type = insert(:content_type, creator: user, organisation: organisation)

      instance_without_vendor =
        insert(:instance,
          creator: user,
          content_type: content_type,
          organisation: organisation,
          vendor: nil
        )

      conn =
        delete(
          conn,
          "/api/v1/contents/#{instance_without_vendor.id}/vendors/#{vendor.id}"
        )

      response = json_response(conn, 200)

      assert response["instance"]["id"] == instance_without_vendor.id
      assert response["vendor"] == nil
    end
  end

  # Helper functions for setup
  defp create_user_and_vendor(%{conn: conn}) do
    user = conn.assigns.current_user
    organisation = List.first(user.owned_organisations)
    vendor = insert(:vendor, creator: user, organisation: organisation)

    %{conn: conn, user: user, vendor: vendor}
  end

  defp create_document_instance(%{conn: conn, user: user, vendor: vendor}) do
    organisation = List.first(user.owned_organisations)
    content_type = insert(:content_type, creator: user, organisation: organisation)

    instance =
      insert(:instance,
        creator: user,
        content_type: content_type,
        organisation: organisation,
        vendor: nil
      )

    %{conn: conn, instance: instance, vendor: vendor}
  end

  defp create_document_instance_with_vendor(%{conn: conn, user: user, vendor: vendor}) do
    organisation = List.first(user.owned_organisations)
    content_type = insert(:content_type, creator: user, organisation: organisation)

    instance =
      insert(:instance,
        creator: user,
        content_type: content_type,
        vendor: vendor,
        organisation: organisation
      )

    %{conn: conn, instance: instance, vendor: vendor}
  end
end
