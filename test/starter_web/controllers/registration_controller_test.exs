defmodule WraftDocWeb.Api.V1.RegistrationControllerTest do
  import WraftDoc.Factory
  use WraftDocWeb.ConnCase

  @valid_attrs %{
    "name" => "wraft user",
    "email" => "user@wraftmail.com",
    "password" => "encrypted"
  }
  @invalid_attrs %{name: "wraft user", email: "email"}

  setup %{conn: conn} do
    {:ok, %{conn: conn}}
  end

  test "register users for valid attrs", %{conn: conn} do
    insert(:organisation)
    insert(:role)

    conn =
      post(conn, Routes.v1_registration_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_user")

    assert json_response(conn, 201)["user"]["name"] == @valid_attrs["name"]
    assert json_response(conn, 201)["user"]["email"] == @valid_attrs["email"]
  end

  test "render error for invalid attributes", %{conn: conn} do
    insert(:organisation)
    insert(:role)

    conn =
      post(conn, Routes.v1_registration_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_user")

    assert json_response(conn, 422)["errors"]["email"] == ["has invalid format"]
    assert json_response(conn, 422)["errors"]["password"] == ["can't be blank"]
  end
end
