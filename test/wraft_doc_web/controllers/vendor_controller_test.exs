defmodule WraftDocWeb.Api.V1.VendorControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Vendor, Repo}

  @valid_attrs %{
    name: "a sample Name",
    email: "a sample Email",
    phone: "a sample Phone",
    address: "a sample Address",
    gstin: "a sample Gstin",
    reg_no: "a sample RegNo",
    contact_person: "a sample ContactPerson"
  }

  @invalid_attrs %{email: nil}

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

      conn =
        conn
        |> post(Routes.v1_vendor_path(conn, :create, @invalid_attrs))
        |> doc(operation_id: "create_resource")

      assert json_response(conn, 422)["errors"]["email"] == ["can't be blank"]
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

      conn =
        conn
        |> put(Routes.v1_vendor_path(conn, :update, vendor.id, @invalid_attrs))
        |> doc(operation_id: "update_resource")

      assert json_response(conn, 422)["errors"]["email"] == ["can't be blank"]
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
end
