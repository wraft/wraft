defmodule WraftDocWeb.Api.V1.OrganisationControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory

  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.InvitedUsers
  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDoc.Repo

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

  describe "create/2" do
    test "create organisation for valid attrs", %{conn: conn} do
      FunWithFlags.enable(:waiting_list_organisation_create_control,
        for_actor: %{email: conn.assigns.current_user.email}
      )

      insert(:plan, name: "Free Trial")
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

    test "doesn't create for invalid attributes", %{conn: conn} do
      FunWithFlags.enable(:waiting_list_organisation_create_control,
        for_actor: %{email: conn.assigns.current_user.email}
      )

      count_before = Organisation |> Repo.all() |> length

      conn = post(conn, Routes.v1_organisation_path(conn, :create, @invalid_attrs))

      assert json_response(conn, 422) == %{
               "errors" => %{"legal_name" => ["can't be blank"], "email" => ["can't be blank"]}
             }

      assert count_before == Organisation |> Repo.all() |> length
    end

    test "return error when waiting_list_organisation_create_control flag is disabled for current user",
         %{conn: conn} do
      insert(:plan, name: "Free Trial")

      conn =
        conn
        |> post(Routes.v1_organisation_path(conn, :create, @valid_attrs))
        |> doc(operation_id: "create_organisation")

      assert json_response(conn, 401) == "User does not have privilege to create an organisation!"
    end
  end

  test "updates organisation for valid attributes", %{conn: conn} do
    %{id: user_id} = insert(:user)
    organisation = insert(:organisation)
    params = Map.put(@valid_attrs, "creator_id", user_id)

    count_before = Organisation |> Repo.all() |> length

    conn = put(conn, Routes.v1_organisation_path(conn, :update, organisation), params)

    assert Organisation |> Repo.all() |> length == count_before
    assert json_response(conn, 200)["name"] == @valid_attrs["name"]
    assert json_response(conn, 200)["address"] == @valid_attrs["address"]
  end

  test "renders organisation details on show", %{conn: conn} do
    organisation = insert(:organisation)

    conn = get(conn, Routes.v1_organisation_path(conn, :show, organisation.id))
    assert json_response(conn, 200)["name"] == organisation.name
    assert json_response(conn, 200)["address"] == organisation.address
  end

  test " Error not found for  organisation id does not exist", %{conn: conn} do
    conn = get(conn, Routes.v1_organisation_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The id does not exist..!"
  end

  test "deletes organisation and render the details", %{conn: conn} do
    organisation = insert(:organisation)

    count_before = Organisation |> Repo.all() |> length
    conn = delete(conn, Routes.v1_organisation_path(conn, :delete, organisation))

    assert Organisation |> Repo.all() |> length == count_before - 1
    assert json_response(conn, 200)["name"] == organisation.name
    assert json_response(conn, 200)["address"] == organisation.address
  end

  # TODO - Add more tests for failure cases
  describe "invite/2" do
    test "invite persons send the mail to the persons mail", %{conn: conn} do
      role =
        insert(:role,
          name: "editor",
          organisation: List.first(conn.assigns.current_user.owned_organisations)
        )

      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com",
          role_id: role.id
        })

      assert json_response(conn, 200) == %{"info" => "Invited successfully.!"}

      assert FunWithFlags.enabled?(:waiting_list_registration_control,
               for: %{email: "msadi@gmail.com"}
             )
    end

    test "creates a new invited user after successfully inviting", %{conn: conn} do
      %{id: organisation_id} = List.first(conn.assigns.current_user.owned_organisations)

      role =
        insert(:role,
          name: "editor",
          organisation: List.first(conn.assigns.current_user.owned_organisations)
        )

      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com",
          role_id: role.id
        })

      assert json_response(conn, 200) == %{"info" => "Invited successfully.!"}

      assert %InvitedUser{status: "invited"} =
               InvitedUsers.get_invited_user("msadi@gmail.com", organisation_id)
    end
  end

  describe "members/2" do
    test "returns the list of all members of current user's organisation", %{conn: conn} do
      user1 = conn.assigns[:current_user]
      [organisation] = user1.owned_organisations

      user2 = insert(:user)
      insert(:user_organisation, user: user2, organisation: organisation)

      user3 = insert(:user)
      insert(:user_organisation, user: user3, organisation: organisation)

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :members, organisation, %{page: 1})
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
      [organisation] = user1.owned_organisations

      user2 = insert(:user, name: "John")
      insert(:user_organisation, user: user2, organisation: organisation)

      user3 = insert(:user, name: "John Doe")
      insert(:user_organisation, user: user3, organisation: organisation)

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :members, organisation, %{page: 1, name: "joh"})
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
      user = conn.assigns[:current_user]
      [organisation] = user.owned_organisations

      user2 = insert(:user, name: "John")
      insert(:user_organisation, user: user2, organisation: organisation)

      user3 = insert(:user, name: "John Doe")

      insert(:user_organisation,
        user: user3,
        organisation: organisation,
        deleted_at: NaiveDateTime.local_now()
      )

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :members, organisation)
        )

      json_response(conn, 200)

      assert length(json_response(conn, 200)["members"]) == 2
      assert User |> Repo.all() |> length() == 3
    end
  end

  describe "index" do
    setup %{conn: conn} do
      role = insert(:role, name: "super_admin")
      insert(:user_role, role: role, user: conn.assigns[:current_user])
      :ok
    end

    test "list all existing organisation details", %{conn: conn} do
      o1 = insert(:organisation)
      o2 = insert(:organisation)

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

    test "search organisation by name", %{conn: conn} do
      insert(:organisation, name: "ABC Ectr")
      insert(:organisation, name: "KDY soft")

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

  describe "delete_user/2" do
    # TODO Write test for user who exist in the current organisation  SUCCESS/FAILURE CASE
    # TODO Write test to check if the current_user has permission to
    #      delete a user from the organisation SUCCESS/FAILURE CASE
  end
end
