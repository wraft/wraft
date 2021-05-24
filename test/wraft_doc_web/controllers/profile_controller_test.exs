defmodule WraftDocWeb.Api.V1.ProfileControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.Repo

  @valid_attrs %{
    name: "John Doe",
    dob: 2020 |> Date.new(2, 29) |> elem(1),
    gender: "male"
  }

  setup %{conn: conn} do
    profile = insert(:profile)
    user = Repo.preload(profile.user, [:profile])

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

  describe "update/2" do
    test "updates profile on valid attributes", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = put(conn, Routes.v1_profile_path(conn, :update), @valid_attrs)
      assert json_response(conn, 200)["name"] == @valid_attrs.name
    end

    test "does not update profile and returns error on invalid attributes", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = put(conn, Routes.v1_profile_path(conn, :update), %{name: ""})
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "show_current_profile/2" do
    test "renders current profile ", %{conn: conn} do
      current_user = conn.assigns.current_user
      insert(:membership, organisation: current_user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_profile_path(conn, :show_current_profile))

      assert json_response(conn, 200)["name"] == current_user.name
    end
  end
end
