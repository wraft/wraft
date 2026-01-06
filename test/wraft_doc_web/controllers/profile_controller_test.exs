defmodule WraftDocWeb.Api.V1.ProfileControllerTest do
  # DO_ME
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

    test "does not update profile and returns error on image size greater than 1 MB", %{
      conn: conn
    } do
      profile_pic = %Plug.Upload{
        content_type: "image/jpg",
        path: File.cwd!() <> "/priv/static/images/over_limit_sized_image.jpg",
        filename: "over_limit_sized_image.jpg"
      }

      attrs =
        Map.merge(@valid_attrs, %{profile_pic: profile_pic, user_id: conn.assigns.current_user.id})

      conn = put(conn, Routes.v1_profile_path(conn, :update), attrs)
      assert json_response(conn, 422)["errors"]["profile_pic"] == ["is invalid"]
    end
  end

  describe "show_current_profile/2" do
    test "renders current profile ", %{conn: conn} do
      current_user = conn.assigns.current_user

      WraftDoc.Repo.get_by(WraftDoc.Account.Profile, user_id: current_user.id) ||
        insert(:profile, user: current_user)

      current_user = WraftDoc.Repo.preload(current_user, :profile)
      conn = assign(conn, :current_user, current_user)

      conn = get(conn, Routes.v1_profile_path(conn, :show_current_profile))

      assert json_response(conn, 200)["name"] == current_user.name
    end
  end
end
