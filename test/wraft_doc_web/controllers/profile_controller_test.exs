defmodule WraftDocWeb.Api.V1.ProfileControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory

  @valid_attrs %{
    name: "John Doe",
    dob: 2020 |> Date.new(2, 29) |> elem(1),
    gender: "male"
  }

  setup %{conn: conn} do
    user = conn.assigns[:current_user]
    insert(:profile, name: user.name, user: user)
    :ok
  end

  describe "update/2" do
    test "updates profile on valid attributes", %{conn: conn} do
      conn = put(conn, Routes.v1_profile_path(conn, :update), @valid_attrs)
      assert json_response(conn, 200)["name"] == @valid_attrs.name
    end

    test "does not update profile and returns error on invalid attributes", %{conn: conn} do
      conn = put(conn, Routes.v1_profile_path(conn, :update), %{name: ""})
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "show_current_profile/2" do
    test "renders current profile ", %{conn: conn} do
      current_user = conn.assigns.current_user

      conn = get(conn, Routes.v1_profile_path(conn, :show_current_profile))

      assert json_response(conn, 200)["name"] == current_user.name
    end
  end
end
