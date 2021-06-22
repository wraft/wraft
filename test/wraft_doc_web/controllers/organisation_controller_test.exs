defmodule WraftDocWeb.Api.V1.OrganisationControllerTest do
  import WraftDoc.Factory
  alias WraftDoc.{Account.User, Enterprise.Organisation, Repo}
  use WraftDocWeb.ConnCase
  @moduletag :controller

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
    role = insert(:role, name: "super_admin")
    user = insert(:user)
    insert(:user_role, role: role, user: user)
    insert(:profile, user: user)

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
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length

    conn =
      conn
      |> post(Routes.v1_organisation_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_organisation")

    assert json_response(conn, 200)["name"] == @valid_attrs["name"]
    assert json_response(conn, 200)["address"] == @valid_attrs["address"]
    assert json_response(conn, 200)["gstin"] == @valid_attrs["gstin"]
    assert json_response(conn, 200)["email"] == @valid_attrs["email"]
    assert json_response(conn, 200)["phone"] == @valid_attrs["phone"]
    assert count_before + 1 == Organisation |> Repo.all() |> length
  end

  test "doens't create for invalid attributes", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length

    conn = post(conn, Routes.v1_organisation_path(conn, :create, @invalid_attrs))

    assert json_response(conn, 422) == %{
             "errors" => %{"legal_name" => ["can't be blank"], "email" => ["can't be blank"]}
           }

    assert count_before == Organisation |> Repo.all() |> length
  end

  test "updates organisation for valid attributes", %{conn: conn} do
    organisation = insert(:organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length

    conn = put(conn, Routes.v1_organisation_path(conn, :update, organisation), @valid_attrs)

    assert Organisation |> Repo.all() |> length == count_before
    assert json_response(conn, 200)["name"] == @valid_attrs["name"]
    assert json_response(conn, 200)["address"] == @valid_attrs["address"]
  end

  test "renders organisation details on show", %{conn: conn} do
    organisation = insert(:organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_organisation_path(conn, :show, organisation.id))
    assert json_response(conn, 200)["name"] == organisation.name
    assert json_response(conn, 200)["address"] == organisation.address
  end

  test " Error not found for  organisation id does not exist", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_organisation_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The id does not exist..!"
  end

  test "deletes organisation and render the details", %{conn: conn} do
    organisation = insert(:organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Organisation |> Repo.all() |> length
    conn = delete(conn, Routes.v1_organisation_path(conn, :delete, organisation))

    assert Organisation |> Repo.all() |> length == count_before - 1
    assert json_response(conn, 200)["name"] == organisation.name
    assert json_response(conn, 200)["address"] == organisation.address
  end

  test "invite persons send the mail to the persons mail", %{conn: conn} do
    organisation = conn.assigns.current_user.organisation
    role = insert(:role)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      post(conn, Routes.v1_organisation_path(conn, :invite, organisation), %{
        email: "msadi@gmail.com",
        role_id: role.id
      })

    assert json_response(conn, 200) == %{"info" => "Invited successfully.!"}
  end

  describe "members/2" do
    test "returns the list of all members of current user's organisation", %{conn: conn} do
      user1 = conn.assigns[:current_user]
      user2 = insert(:user, organisation: user1.organisation)
      insert(:profile, user: user2)
      user3 = insert(:user, organisation: user1.organisation)
      insert(:profile, user: user3)

      conn = put_req_header(build_conn(), "authorization", "Bearer #{conn.assigns.token}")

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :members, user1.organisation, %{page: 1})
        )

      user_ids =
        json_response(conn, 200)["members"] |> Enum.map(fn x -> x["id"] end) |> to_string()

      assert user_ids =~ user1.id
      assert user_ids =~ user2.id
      assert user_ids =~ user3.id
      assert json_response(conn, 200)["page_number"] == 1
      assert json_response(conn, 200)["total_pages"] == 1
      assert json_response(conn, 200)["total_entries"] == 3
    end

    test "returns the list of all members of current user's organisation matching the given name",
         %{conn: conn} do
      user1 = conn.assigns[:current_user]
      user2 = insert(:user, organisation: user1.organisation, name: "John")
      insert(:profile, user: user2)
      user3 = insert(:user, organisation: user1.organisation, name: "John Doe")
      insert(:profile, user: user3)

      conn = put_req_header(build_conn(), "authorization", "Bearer #{conn.assigns.token}")

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :members, user1.organisation, %{page: 1, name: "joh"})
        )

      user_ids =
        json_response(conn, 200)["members"] |> Enum.map(fn x -> x["id"] end) |> to_string()

      refute user_ids =~ user1.id
      assert user_ids =~ user2.id
      assert user_ids =~ user3.id
      assert json_response(conn, 200)["page_number"] == 1
      assert json_response(conn, 200)["total_pages"] == 1
      assert json_response(conn, 200)["total_entries"] == 2
    end

    test "only list existing members ", %{conn: conn} do
      user1 = conn.assigns[:current_user]
      user2 = insert(:user, organisation: user1.organisation, name: "John")
      insert(:profile, user: user2)

      user3 =
        insert(:user,
          organisation: user1.organisation,
          name: "John Doe",
          deleted_at: NaiveDateTime.local_now()
        )

      insert(:profile, user: user3)
      conn = put_req_header(build_conn(), "authorization", "Bearer #{conn.assigns.token}")

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :members, user1.organisation)
        )

      assert length(json_response(conn, 200)["members"]) == 2
      assert User |> Repo.all() |> length() == 3
    end
  end

  describe "index" do
    test "list all existing organisation details", %{conn: conn} do
      o1 = insert(:organisation)
      o2 = insert(:organisation)

      conn = put_req_header(build_conn(), "authorization", "Bearer #{conn.assigns.token}")

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :index, %{page: 1})
        )

      assert conn
             |> json_response(200)
             |> get_in(["organisations"])
             |> Enum.map(fn x -> x["name"] end)
             |> to_string() =~ o1.name

      assert conn
             |> json_response(200)
             |> get_in(["organisations"])
             |> Enum.map(fn x -> x["address"] end)
             |> to_string() =~ o2.address
    end
  end

  test "search organisation by name", %{conn: conn} do
    insert(:organisation, name: "ABC Ectr")
    insert(:organisation, name: "KDY soft")

    conn = put_req_header(build_conn(), "authorization", "Bearer #{conn.assigns.token}")

    conn =
      get(
        conn,
        Routes.v1_organisation_path(conn, :index, %{page: 1, name: "KDY"})
      )

    assert length(json_response(conn, 200)["organisations"]) == 1
    # assert json_response(conn, 200)["organisations"]
    #        |> Enum.map(fn x -> x["name"] end)
    #        |> to_string() =~ o1.name

    # assert json_response(conn, 200)["organisations"]
    #        |> Enum.map(fn x -> x["address"] end)
    #        |> to_string() =~ o2.address
  end
end
