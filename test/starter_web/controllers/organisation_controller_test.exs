defmodule WraftDocWeb.Api.V1.OrganisationControllerTest do
  import WraftDoc.Factory
  alias WraftDoc.{Repo, Enterprise.Organisation}
  use WraftDocWeb.ConnCase

  @valid_attrs %{
    "name" => "ABC enterprices",
    "legal_name" => "ABC enterprices LLC",
    "address" => "#24, XV Building, TS DEB Layout ",
    "gstin" => "32AA65FF56545353",
    "email" => "abcent@gmail.com",
    "phone" => "865623232"
  }

  @invalid_attrs %{name: "abc"}

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

  test "create organisation for valid attrs", %{conn: conn} do
    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length

    conn =
      post(conn, Routes.v1_organisation_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_organisation")

    assert json_response(conn, 201)["name"] == @valid_attrs["name"]
    assert json_response(conn, 201)["address"] == @valid_attrs["address"]
    assert json_response(conn, 201)["gstin"] == @valid_attrs["gstin"]
    assert json_response(conn, 201)["email"] == @valid_attrs["email"]
    assert json_response(conn, 201)["phone"] == @valid_attrs["phone"]
    assert count_before + 1 == Organisation |> Repo.all() |> length
  end

  test "doens't create for invalid attributes", %{conn: conn} do
    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length

    conn = post(conn, Routes.v1_organisation_path(conn, :create, @invalid_attrs))
    assert json_response(conn, 422) == %{"errors" => %{"legal_name" => ["can't be blank"]}}
    assert count_before == Organisation |> Repo.all() |> length
  end

  test "updates organisation for valid attributes", %{conn: conn} do
    organisation = insert(:organisation)

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length

    conn = put(conn, Routes.v1_organisation_path(conn, :update, organisation.uuid), @valid_attrs)

    assert Organisation |> Repo.all() |> length == count_before
    assert json_response(conn, 201)["name"] == @valid_attrs["name"]
    assert json_response(conn, 201)["address"] == @valid_attrs["address"]
  end

  test "renders organisation details on show", %{conn: conn} do
    organisation = insert(:organisation)

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_organisation_path(conn, :show, organisation.uuid))
    assert json_response(conn, 200)["name"] == organisation.name
    assert json_response(conn, 200)["address"] == organisation.address
  end

  test " Error not found for  organisation id does not exist", %{conn: conn} do
    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_organisation_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "deletes organisation and render the details", %{conn: conn} do
    organisation = insert(:organisation)

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length
    conn = delete(conn, Routes.v1_organisation_path(conn, :delete, organisation.uuid))

    assert Organisation |> Repo.all() |> length == count_before - 1
    assert json_response(conn, 200)["name"] == organisation.name
    assert json_response(conn, 200)["address"] == organisation.address
  end

  test "invite persons send the mail to the persons mail", %{conn: conn} do
    organisation = conn.assigns.current_user.organisation

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      post(conn, Routes.v1_organisation_path(conn, :invite, organisation.uuid), %{
        email: "msadi@gmail.com"
      })

    assert json_response(conn, 200) == %{"info" => "Invited successfully.!"}
  end
end
