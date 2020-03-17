defmodule WraftDocWeb.Api.V1.OrganisationControllerTest do
  import WraftDoc.Factory
  use WraftDocWeb.ConnCase
  require IEx

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
    user = insert(:user)

    conn =
      post(
        conn,
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    {:ok, %{conn: conn}}
  end

  test "create organisation for valid attrs", %{conn: conn} do
    conn = post(conn, Routes.v1_organisation_path(conn, :create, @valid_attrs))
  end
end
