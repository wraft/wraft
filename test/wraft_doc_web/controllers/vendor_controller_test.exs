defmodule WraftDocWeb.VendorControllerTest do
  use WraftDocWeb.ConnCase

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
  setup %{conn: conn} do
    role = insert(:role, name: "admin")
    user = insert(:user, role: role)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    conn = assign(conn, :current_user, user)

    {:ok, %{conn: conn}}
  end

  describe "create/2" do
    test "create vendors by valid attrrs", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      count_before = Vendor |> Repo.all() |> length()

      conn =
        conn
        |> post(conn, Routes.v1_vendor_path(conn, :create, @valid_attrs))
        |> doc(operation_id: "create_resource")

      assert count_before + 1 == Vendor |> Repo.all() |> length()
      assert json_response(conn, 200)["email"] == @valid_attrs.email
    end

    test "does not create vendors by invalid attrs", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

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
      vendor = insert(:vendor, organisation: user.organisation, creator: user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      count_before = Vendor |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_vendor_path(conn, :update, vendor.uuid, @valid_attrs))
        |> doc(operation_id: "update_resource")

      assert json_response(conn, 200)["email"] == @valid_attrs.email
      assert count_before == Vendor |> Repo.all() |> length()
    end

    test "does't update vendors for invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: user.organisation, creator: user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn =
        conn
        |> put(Routes.v1_vendor_path(conn, :update, vendor.uuid, @invalid_attrs))
        |> doc(operation_id: "update_resource")

      assert json_response(conn, 422)["errors"]["email"] == ["can't be blank"]
    end
  end

  describe "index/2" do
    test "index lists vendor by current user", %{conn: conn} do
      user = conn.assigns.current_user

      a1 = insert(:vendor, organisation: user.organisation, creator: user)
      a2 = insert(:vendor, organisation: user.organisation, creator: user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

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
      vendor = insert(:vendor, organisation: user.organisation, creator: user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_vendor_path(conn, :show, vendor.uuid))

      assert json_response(conn, 200)["email"] == vendor.email
    end

    test "error not found for id does not exists", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_vendor_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "delete" do
    test "delete vendor by given id", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      user = conn.assigns.current_user
      vendor = insert(:vendor, organisation: user.organisation, creator: user)
      count_before = Vendor |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_vendor_path(conn, :delete, vendor.uuid))
      assert count_before - 1 == Vendor |> Repo.all() |> length()
      assert json_response(conn, 200)["email"] == vendor.email
    end
  end
end
