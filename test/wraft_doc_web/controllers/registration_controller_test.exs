defmodule WraftDocWeb.Api.V1.RegistrationControllerTest do
  import WraftDoc.Factory
  use WraftDocWeb.ConnCase

  @moduletag :controller

  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Repo

  @valid_attrs %{
    "name" => "wraft user",
    "email" => "user@wraftmail.com",
    "password" => "encrypted"
  }
  @invalid_attrs %{"name" => "wraft user", "email" => "email"}

  setup do
    FunWithFlags.enable(:waiting_list_registration_control,
      for_actor: %{email: @valid_attrs["email"]}
    )

    FunWithFlags.enable(:waiting_list_registration_control,
      for_actor: %{email: @invalid_attrs["email"]}
    )

    {:ok, %{conn: build_conn()}}
  end

  describe "registration/1" do
    # FIXME need to fix this
    test "succesfully registers users with valid attrs and organisation invite token", %{
      conn: conn
    } do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")
      params = Map.put(@valid_attrs, "token", token)

      conn =
        conn
        |> post(Routes.v1_registration_path(conn, :create, params))
        |> doc(operation_id: "create_user")

      assert json_response(conn, 201)["user"]["name"] == @valid_attrs["name"]
      assert json_response(conn, 201)["user"]["email"] == @valid_attrs["email"]
      assert json_response(conn, 200)["user"]["organisation_id"]
      assert json_response(conn, 200)["user"]["roles"] != []
      assert json_response(conn, 201)["access_token"] != nil
      assert json_response(conn, 201)["refresh_token"] != nil

      assert ["Personal", organisation.name] ==
               Enum.map(json_response(conn, 201)["organisations"], & &1["name"])
    end

    test "succesfully registers users with valid attrs and without organisation invite token", %{
      conn: conn
    } do
      conn =
        conn
        |> post(Routes.v1_registration_path(conn, :create, @valid_attrs))
        |> doc(operation_id: "create_user")

      assert json_response(conn, 201)["user"]["name"] == @valid_attrs["name"]
      assert json_response(conn, 201)["user"]["email"] == @valid_attrs["email"]
      assert json_response(conn, 201)["access_token"] != nil
      assert json_response(conn, 201)["refresh_token"] != nil
      assert Enum.at(json_response(conn, 201)["organisations"], 0)["name"] == "Personal"
    end

    # FIXME need to fix this
    test "register as admin if token contains admin role", %{conn: conn} do
      organisation = insert(:organisation)
      role = insert(:role, name: "super_admin", organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")
      params = Map.put(@valid_attrs, "token", token)
      count_before = User |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_registration_path(conn, :create, params))
        |> doc(operation_id: "create_user")

      count_after = User |> Repo.all() |> length()
      assert count_before + 1 == count_after
      assert json_response(conn, 201)["user"]["name"] == @valid_attrs["name"]
      assert json_response(conn, 201)["user"]["email"] == @valid_attrs["email"]
      assert json_response(conn, 201)["access_token"] != nil
      assert json_response(conn, 201)["refresh_token"] != nil
    end

    test "invite auth token is deleted on successfull registration", %{conn: conn} do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")

      params = Map.put(@valid_attrs, "token", token)

      conn
      |> post(Routes.v1_registration_path(conn, :create, params))
      |> doc(operation_id: "create_user")

      Repo.all(AuthToken)
    end

    test "render error for invalid attributes with organisation invite link", %{conn: conn} do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @invalid_attrs["email"],
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")
      params = Map.put(@invalid_attrs, "token", token)

      conn =
        conn
        |> post(Routes.v1_registration_path(conn, :create, params))
        |> doc(operation_id: "create_user")

      assert json_response(conn, 422)["errors"]["email"] == ["has invalid format"]
      assert json_response(conn, 422)["errors"]["password"] == ["can't be blank"]
    end

    test "render error for invalid attributes without organisation invite link", %{conn: conn} do
      conn =
        conn
        |> post(Routes.v1_registration_path(conn, :create, @invalid_attrs))
        |> doc(operation_id: "create_user")

      assert json_response(conn, 422)["errors"]["email"] == ["has invalid format"]
      assert json_response(conn, 422)["errors"]["password"] == ["can't be blank"]
    end

    test "render error when flag is disabled", %{conn: conn} do
      FunWithFlags.disable(:waiting_list_registration_control,
        for_actor: %{email: @valid_attrs["email"]}
      )

      conn =
        conn
        |> post(Routes.v1_registration_path(conn, :create, @valid_attrs))
        |> doc(operation_id: "create_user")

      assert json_response(conn, 401) == "Given email is not approved!"
    end
  end
end
