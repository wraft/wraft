defmodule WraftDocWeb.Api.V1.RegistrationControllerTest do
  import WraftDoc.Factory
  use WraftDocWeb.ConnCase

  @moduletag :controller

  alias WraftDoc.{Account.User, Repo}

  @valid_attrs %{
    "name" => "wraft user",
    "email" => "user@wraftmail.com",
    "password" => "encrypted"
  }
  @invalid_attrs %{"name" => "wraft user", "email" => "email"}

  setup %{conn: conn} do
    {:ok, %{conn: conn}}
  end

  test "register users for valid attrs", %{conn: conn} do
    organisation = insert(:organisation)
    role = insert(:role)

    token =
      WraftDoc.create_phx_token("organisation_invite", %{
        organisation_id: organisation.id,
        email: @valid_attrs["email"],
        role: role.name
      })

    insert(:auth_token, value: token, token_type: "invite")
    params = Map.put(@valid_attrs, "token", token)

    conn =
      conn
      |> post(Routes.v1_registration_path(conn, :create, params))
      |> doc(operation_id: "create_user")

    assert json_response(conn, 201)["user"]["name"] == @valid_attrs["name"]
    assert json_response(conn, 201)["user"]["email"] == @valid_attrs["email"]
  end

  test "register as admin if token contains admin role", %{conn: conn} do
    organisation = insert(:organisation)
    insert(:role, name: "super_admin")

    token =
      WraftDoc.create_phx_token("organisation_invite", %{
        organisation_id: organisation.id,
        email: @valid_attrs["email"],
        role: "super_admin"
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

    assert json_response(conn, 201)["user"]["roles"]
           |> Enum.map(fn x -> x["name"] end)
           |> List.to_string() =~ "super_admin"
  end

  test "invite auth token is deleted on successfull registration", %{conn: conn} do
    organisation = insert(:organisation)
    role = insert(:role)

    token =
      WraftDoc.create_phx_token("organisation_invite", %{
        organisation_id: organisation.id,
        email: @valid_attrs["email"],
        role: role.name
      })

    insert(:auth_token, value: token, token_type: "invite")

    params = Map.put(@valid_attrs, "token", token)

    conn
    |> post(Routes.v1_registration_path(conn, :create, params))
    |> doc(operation_id: "create_user")

    assert_receive({:status, "Deleting Auth Token"})
  end

  test "render error for invalid attributes", %{conn: conn} do
    organisation = insert(:organisation)
    role = insert(:role)

    token =
      WraftDoc.create_phx_token("organisation_invite", %{
        organisation_id: organisation.id,
        email: @invalid_attrs["email"],
        role: role.name
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
end
