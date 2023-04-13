defmodule WraftDocWeb.Api.V1.WaitingListControllerTest do
  @moduledoc """
     Test module for waitlist controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  alias WraftDoc.Repo
  alias WraftDoc.WaitingLists.WaitingList

  @valid_params %{
    "first_name" => "first name",
    "last_name" => "last name",
    "email" => "sample@gmail.com"
  }

  @invalid_params %{}

  setup do
    {:ok, %{conn: build_conn()}}
  end

  describe "create/2" do
    test "Add user to waiting list for valid attribute", %{conn: conn} do
      count_before = WaitingList |> Repo.all() |> length()

      conn = post(conn, Routes.v1_waiting_list_path(conn, :create), @valid_params)

      count_after = WaitingList |> Repo.all() |> length()

      assert count_before + 1 == count_after
      assert response(conn, 200) =~ "Success"
    end

    test "return error for invalid attribute", %{conn: conn} do
      count_before = WaitingList |> Repo.all() |> length()

      conn = post(conn, Routes.v1_waiting_list_path(conn, :create), @invalid_params)

      count_after = WaitingList |> Repo.all() |> length()

      assert count_before == count_after
      assert json_response(conn, 422)["errors"]["email"] == ["can't be blank"]
      assert json_response(conn, 422)["errors"]["first_name"] == ["can't be blank"]
      assert json_response(conn, 422)["errors"]["last_name"] == ["can't be blank"]
    end

    test "returns error when registered email tries to join waitlist", %{conn: conn} do
      insert(:user, email: @valid_params["email"])
      conn = post(conn, Routes.v1_waiting_list_path(conn, :create), @valid_params)

      assert json_response(conn, 400)["errors"] == "already in waitlist"
    end
  end
end
