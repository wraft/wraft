defmodule WraftDocWeb.Api.V1.OrganisationControllerTest do
  use WraftDocWeb.ConnCase, async: false

  import WraftDoc.Factory

  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.InvitedUsers
  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDoc.Repo
  alias WraftDocWeb.Endpoint

  @moduletag :controller

  @valid_attrs %{
    "name" => "ABC enterprises",
    "legal_name" => "ABC enterprises LLC",
    "address" => "#24, XV Building, TS DEB Layout ",
    "gstin" => "32AA65FF56545353",
    "email" => "abcent@gmail.com",
    "url" => "wraftdoc@customprofile.com",
    "phone" => "865623232"
  }

  @invalid_attrs %{name: "abc"}

  describe "create/2" do
    test "create organisation for valid attrs", %{conn: conn} do
      FunWithFlags.enable(:waiting_list_organisation_create_control,
        for_actor: %{email: conn.assigns.current_user.email}
      )

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
      assert json_response(conn, 200)["url"] == @valid_attrs["url"]
      assert count_before + 1 == Organisation |> Repo.all() |> length
    end

    test "doesn't create for invalid attributes", %{conn: conn} do
      FunWithFlags.enable(:waiting_list_organisation_create_control,
        for_actor: %{email: conn.assigns.current_user.email}
      )

      count_before = Organisation |> Repo.all() |> length

      conn = post(conn, Routes.v1_organisation_path(conn, :create, @invalid_attrs))

      assert json_response(conn, 422) == %{"errors" => %{"email" => ["can't be blank"]}}

      assert count_before == Organisation |> Repo.all() |> length
    end

    test "return error when waiting_list_organisation_create_control flag is disabled for current user",
         %{conn: conn} do
      conn =
        conn
        |> post(Routes.v1_organisation_path(conn, :create, @valid_attrs))
        |> doc(operation_id: "create_organisation")

      assert json_response(conn, 401) == "User does not have privilege to create an organisation!"
    end

    test "return error when logo file size limit exceeded", %{conn: conn} do
      FunWithFlags.enable(:waiting_list_organisation_create_control,
        for_actor: %{email: conn.assigns.current_user.email}
      )

      logo = %Plug.Upload{
        content_type: "image/jpg",
        path: File.cwd!() <> "/priv/static/wraft_files/over_limit_sized_image.jpg",
        filename: "over_limit_sized_image.jpg"
      }

      conn =
        post(
          conn,
          Routes.v1_organisation_path(conn, :create),
          Map.merge(@valid_attrs, %{"logo" => logo})
        )

      assert json_response(conn, 422) == %{"errors" => %{"logo" => ["is invalid"]}}
    end
  end

  test "updates organisation for valid attributes", %{conn: conn} do
    organisation = insert(:organisation)

    conn = put(conn, Routes.v1_organisation_path(conn, :update, organisation), @valid_attrs)

    assert json_response(conn, 200)["name"] == @valid_attrs["name"]
    assert json_response(conn, 200)["address"] == @valid_attrs["address"]
    assert json_response(conn, 200)["url"] == @valid_attrs["url"]
  end

  test "uploads new logo for organisation", %{conn: conn} do
    user = conn.assigns.current_user
    [organisation] = user.owned_organisations

    params =
      Map.put(@valid_attrs, "logo", %Plug.Upload{
        content_type: "image/png",
        path: File.cwd!() <> "/priv/static/images/logo.png",
        filename: "logo.png"
      })

    conn = put(conn, Routes.v1_organisation_path(conn, :update, organisation), params)

    assert json_response(conn, 200)["logo"] =~
             "#{System.get_env("MINIO_URL")}/organisations/#{organisation.id}/logo/logo_#{organisation.id}.png"
  end

  test "does not update name of personal organisation", %{conn: conn} do
    user = insert(:user_with_personal_organisation)

    organisation = List.first(user.owned_organisations)
    role = insert(:role, organisation: organisation)
    insert(:user_role, user: user, role: role)
    user = Repo.preload(user, [:user_roles, :roles])

    role_names = Enum.map(user.roles, & &1.name)
    permissions = user.roles |> Enum.flat_map(& &1.permissions) |> Enum.uniq()

    user =
      Map.merge(user, %{
        role_names: role_names,
        permissions: permissions,
        current_org_id: organisation.id
      })

    # Create token with organization context
    {:ok, token, _} =
      WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: organisation.id},
        token_type: "access",
        ttl: {2, :hour}
      )

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("accept", "application/json")
      |> assign(:current_user, user)
      |> assign(:organisation_id, organisation.id)

    conn = put(conn, Routes.v1_organisation_path(conn, :update, organisation.id), @valid_attrs)

    if conn.status == 200 do
      response = json_response(conn, 200)

      refute response["name"] == @valid_attrs["name"]
      assert String.starts_with?(response["name"], "Personal")
      assert response["address"] == @valid_attrs["address"]
      assert response["url"] == @valid_attrs["url"]
    else
      # If not successful, show the error
      raise "Expected 200 status"
    end
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

  describe "delete/2" do
    test "deletes organisation and render the details", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      personal_org = insert(:organisation, name: "Personal", creator: user, email: user.email)
      role = insert(:role, organisation: personal_org)
      insert(:user_role, user: user, role: role)

      delete_code = 100_000..999_999 |> Enum.random() |> Integer.to_string()

      insert(:auth_token,
        value: "#{organisation.id}:#{delete_code}",
        token_type: "delete_organisation",
        user: conn.assigns.current_user
      )

      count_before = Organisation |> Repo.all() |> length
      conn = delete(conn, Routes.v1_organisation_path(conn, :delete, %{"code" => delete_code}))

      assert count_before - 1 == Organisation |> Repo.all() |> length
      assert Organisation |> Repo.all() |> length == count_before - 1
      assert json_response(conn, 200)["organisation"]["name"] == organisation.name
      assert json_response(conn, 200)["organisation"]["address"] == organisation.address
      assert json_response(conn, 200)["user"]["name"] == user.name
      assert json_response(conn, 200)["user"]["email"] == user.email
      assert json_response(conn, 200)["access_token"] != nil
      assert json_response(conn, 200)["refresh_token"] != nil
    end

    test "return error if the token is invalid", %{conn: conn} do
      conn = delete(conn, Routes.v1_organisation_path(conn, :delete, %{"token" => "invalid"}))
      assert json_response(conn, 403)["errors"] == "You are not authorized for this action.!"
    end

    test "return error if user is not member of the organisation" do
      user = insert(:user_with_personal_organisation)
      [organisation] = user.owned_organisations
      role = WraftDoc.Factory.insert(:role, organisation: organisation)
      WraftDoc.Factory.insert(:user_role, user: user, role: role)
      user = Repo.preload(user, [:user_roles, :roles])

      role_names = Enum.map(user.roles, & &1.name)
      permissions = user.roles |> Enum.flat_map(& &1.permissions) |> Enum.uniq()

      user =
        Map.merge(user, %{
          role_names: role_names,
          permissions: permissions,
          current_org_id: organisation.id
        })

      {:ok, token, _} =
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: organisation.id})

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> Plug.Conn.assign(:current_user, user)

      conn = delete(conn, Routes.v1_organisation_path(conn, :delete, %{}))
      assert json_response(conn, 401)["errors"] == "User is not a member of this organisation!"
    end

    test "returns error when trying to delete personal organisation" do
      user = insert(:user_with_personal_organisation)
      [organisation] = user.owned_organisations
      insert(:user_organisation, user: user, organisation: organisation)
      role = WraftDoc.Factory.insert(:role, organisation: organisation)
      WraftDoc.Factory.insert(:user_role, user: user, role: role)
      user = Repo.preload(user, [:user_roles, :roles])

      role_names = Enum.map(user.roles, & &1.name)
      permissions = user.roles |> Enum.flat_map(& &1.permissions) |> Enum.uniq()

      user =
        Map.merge(user, %{
          role_names: role_names,
          permissions: permissions,
          current_org_id: organisation.id
        })

      {:ok, token, _} =
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: organisation.id})

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> Plug.Conn.assign(:current_user, user)

      conn = delete(conn, Routes.v1_organisation_path(conn, :delete, %{}))
      assert json_response(conn, 403)["errors"] == "You are not authorized for this action.!"
    end
  end

  describe "request_deletion/2" do
    test "sends the delete request mail to the user's email", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations

      organisation
      |> Ecto.Changeset.change(owner_id: user.id, name: "Test Organisation")
      |> Repo.update!()

      conn = post(conn, Routes.v1_organisation_path(conn, :request_deletion, %{}))
      assert json_response(conn, 200)["info"] == "Delete token email sent!"
    end

    test "return error on attempting to request deletion of personal organisation" do
      user = insert(:user_with_personal_organisation)
      [organisation] = user.owned_organisations
      insert(:user_organisation, user: user, organisation: organisation)
      role = WraftDoc.Factory.insert(:role, organisation: organisation)
      WraftDoc.Factory.insert(:user_role, user: user, role: role)
      user = Repo.preload(user, [:user_roles, :roles])

      role_names = Enum.map(user.roles, & &1.name)
      permissions = user.roles |> Enum.flat_map(& &1.permissions) |> Enum.uniq()

      user =
        Map.merge(user, %{
          role_names: role_names,
          permissions: permissions,
          current_org_id: organisation.id
        })

      {:ok, token, _} =
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: organisation.id})

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> Plug.Conn.assign(:current_user, user)

      conn = post(conn, Routes.v1_organisation_path(conn, :request_deletion, %{}))
      assert json_response(conn, 422)["errors"] == "Can't delete personal organisation"
    end

    test "return error if user is not member of the organisation" do
      user = insert(:user_with_personal_organisation)
      [organisation] = user.owned_organisations
      role = WraftDoc.Factory.insert(:role, organisation: organisation)
      WraftDoc.Factory.insert(:user_role, user: user, role: role)
      user = Repo.preload(user, [:user_roles, :roles])

      role_names = Enum.map(user.roles, & &1.name)
      permissions = user.roles |> Enum.flat_map(& &1.permissions) |> Enum.uniq()

      user =
        Map.merge(user, %{
          role_names: role_names,
          permissions: permissions,
          current_org_id: organisation.id
        })

      {:ok, token, _} =
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: organisation.id})

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> Plug.Conn.assign(:current_user, user)

      conn = post(conn, Routes.v1_organisation_path(conn, :request_deletion, %{}))
      assert json_response(conn, 401)["errors"] == "User is not a member of this organisation!"
    end
  end

  describe "invite/2" do
    test "sends the invitation mail to the persons mail", %{conn: conn} do
      role =
        insert(:role,
          name: "editor",
          organisation: List.first(conn.assigns.current_user.owned_organisations)
        )

      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com",
          role_ids: [role.id]
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
          role_ids: [role.id]
        })

      assert json_response(conn, 200) == %{"info" => "Invited successfully.!"}

      assert %InvitedUser{status: "invited"} =
               InvitedUsers.get_invited_user("msadi@gmail.com", organisation_id)
    end

    test "accepts multiple roles for the user", %{conn: conn} do
      organisation = List.first(conn.assigns.current_user.owned_organisations)

      role_ids =
        ["editor", "admin", "viewer"]
        |> Enum.map(&insert(:role, name: &1, organisation: organisation))
        |> Enum.map(& &1.id)

      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com",
          role_ids: role_ids
        })

      assert json_response(conn, 200) == %{"info" => "Invited successfully.!"}

      assert %InvitedUser{status: "invited"} =
               InvitedUsers.get_invited_user("msadi@gmail.com", organisation.id)
    end

    test "returns an error when email is not provided", %{conn: conn} do
      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          role_ids: [1]
        })

      assert json_response(conn, 400) == %{
               "errors" => "Please provide all necessary datas for this action.!"
             }
    end

    test "returns error when role_ids are not provided", %{conn: conn} do
      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com"
        })

      assert json_response(conn, 404) == %{"errors" => "No roles found"}
    end

    test "only accepts role_ids from the user's organisation", %{conn: conn} do
      organisation = List.first(conn.assigns.current_user.owned_organisations)

      same_organisation_role_ids =
        ["editor", "admin"]
        |> Enum.map(&insert(:role, name: &1, organisation: organisation))
        |> Enum.map(& &1.id)
        |> Enum.sort()

      %{id: viewer_role_id} = insert(:role, name: "viewer")
      role_ids = same_organisation_role_ids ++ [viewer_role_id]

      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com",
          role_ids: role_ids
        })

      %{value: token} =
        Repo.get_by(AuthToken, user_id: conn.assigns.current_user.id, token_type: :invite)

      assert json_response(conn, 200) == %{"info" => "Invited successfully.!"}

      assert %InvitedUser{status: "invited"} =
               InvitedUsers.get_invited_user("msadi@gmail.com", organisation.id)

      assert {:ok, %{roles: ^same_organisation_role_ids}} =
               Phoenix.Token.verify(
                 Endpoint,
                 "organisation_invite",
                 Base.url_decode64!(token),
                 []
               )
    end

    test "returns error when all the role_ids does not belong to user's organisation", %{
      conn: conn
    } do
      role_ids =
        ["editor", "admin", "viewer"] |> Enum.map(&insert(:role, name: &1)) |> Enum.map(& &1.id)

      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com",
          role_ids: role_ids
        })

      assert json_response(conn, 404) == %{"errors" => "No roles found"}
    end

    test "returns 422 error when user is already a member", %{conn: conn} do
      organisation = List.first(conn.assigns.current_user.owned_organisations)
      %{id: role_id} = insert(:role, name: "editor", organisation: organisation)
      user = insert(:user, email: "msadi@gmail.com")
      insert(:user_organisation, user: user, organisation: organisation)

      conn =
        post(conn, Routes.v1_organisation_path(conn, :invite), %{
          email: "msadi@gmail.com",
          role_id: role_id
        })

      assert json_response(conn, 422) == %{"errors" => "User with this email exists.!"}
    end
  end

  describe "members/2" do
    test "returns the list of all members of current user's organisation", %{conn: conn} do
      user1 = conn.assigns[:current_user]
      insert(:profile, user: user1)
      [organisation] = user1.owned_organisations

      user2 = insert(:user)
      insert(:profile, user: user2)
      insert(:user_organisation, user: user2, organisation: organisation)

      user3 = insert(:user)
      insert(:profile, user: user3)
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
      insert(:profile, user: user1)
      [organisation] = user1.owned_organisations

      user2 = insert(:user, name: "John")
      insert(:profile, user: user2)
      insert(:user_organisation, user: user2, organisation: organisation)

      user3 = insert(:user, name: "John Doe")
      insert(:profile, user: user3)
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
      insert(:profile, user: user)
      [organisation] = user.owned_organisations

      user2 = insert(:user, name: "John")
      insert(:profile, user: user2)
      insert(:user_organisation, user: user2, organisation: organisation)

      user3 = insert(:user, name: "John Doe")
      insert(:profile, user: user3)

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

      response = json_response(conn, 200)

      # Count should be 2: current_user + user2 (user3 is deleted)
      assert length(response["members"]) == 2

      # Don't assert exact user count as setup might create extra users
      # Just verify the members endpoint returns the correct count
    end
  end

  describe "index" do
    test "list all existing organisation details", %{conn: conn} do
      o1 = insert(:organisation)
      o2 = insert(:organisation)

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :index, %{page: 1})
        )

      response = json_response(conn, 200)
      organisations = response["organisations"]

      # Check names
      names = Enum.map(organisations, fn x -> x["name"] end)
      assert Enum.any?(names, &(&1 == o1.name))

      # Check addresses - filter out nil values before converting to string
      addresses =
        organisations
        |> Enum.map(& &1["address"])
        |> Enum.reject(&is_nil/1)

      address_string = Enum.join(addresses, " ")
      assert address_string =~ o2.address
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

  describe "verify_invite_token/2" do
    test "verify_invite_token returns 200 and renders the verify_invite_token.json template with the correct data" do
      conn = build_conn()
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: "test@test.com",
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")

      conn = get(conn, Routes.v1_organisation_path(conn, :verify_invite_token, token))

      response = json_response(conn, 200)

      assert response["email"] == "test@test.com"
      assert response["organisation"]["id"] == organisation.id
      assert response["organisation"]["name"] == organisation.name
      assert Map.has_key?(response, "is_organisation_member")
      assert Map.has_key?(response, "is_wraft_member")
    end

    test "verify_invite_token returns 401 and renders the error.json template when the token is invalid" do
      conn = build_conn()

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :verify_invite_token, "invalid_token")
        )

      assert conn.status == 403
      assert json_response(conn, 403) == %{"errors" => "You are not authorized for this action.!"}
    end

    test "verify_invite_token returns 404 and renders the error.json template when the organisation is not found" do
      conn = build_conn()

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: Faker.UUID.v4(),
          email: "test@test.com",
          role: Faker.UUID.v4()
        })

      insert(:auth_token, value: token, token_type: "invite")

      conn =
        get(
          conn,
          Routes.v1_organisation_path(conn, :verify_invite_token, token)
        )

      assert conn.status == 404
      assert json_response(conn, 404) == "Not Found"
    end
  end
end
