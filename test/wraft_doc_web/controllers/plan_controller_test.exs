defmodule WraftDocWeb.Api.V1.PlanControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory

  #  @valid_attrs %{
  #    name: "Basic",
  #    description: "A free plan, with only basic features",
  #    yearly_amount: 0,
  #    monthly_amount: 0
  #  }

  # TODO Can be properly tested only after we decide what router pipelines to use for this action
  #  describe "create/2" do
  #    test "creates a plan with valid attrs", %{conn: conn} do
  #      conn = post(conn, Routes.v1_plan_path(conn, :create), @valid_attrs)
  #      assert json_response(conn, 200)["name"] == @valid_attrs.name
  #      assert json_response(conn, 200)["description"] == @valid_attrs.description
  #      assert json_response(conn, 200)["yearly_amount"] == @valid_attrs.yearly_amount
  #      assert json_response(conn, 200)["monthly_amount"] == @valid_attrs.monthly_amount
  #    end
  #
  #    test "does not create a plan with invalid attrs", %{conn: conn} do
  #      conn = post(conn, Routes.v1_plan_path(conn, :create), %{})
  #      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
  #      assert json_response(conn, 422)["errors"]["description"] == ["can't be blank"]
  #    end
  #
  #    test "does not create a plan if current user is not an admin" do
  #      user = WraftDoc.Factory.insert(:user_with_organisation)
  #      WraftDoc.Factory.insert(:membership, organisation: List.first(user.owned_organisations))
  #
  #      {:ok, token, _} =
  #        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})
  #
  #      conn =
  #        Phoenix.ConnTest.build_conn()
  #        |> Plug.Conn.put_req_header("accept", "application/json")
  #        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
  #        |> Plug.Conn.assign(:current_user, user)
  #
  #      conn = post(conn, Routes.v1_plan_path(conn, :create), %{})
  #
  #      assert json_response(conn, 401)["errors"] == "You are not authorized for this action.!"
  #    end
  #  end

  describe "index/2" do
    test "returns all the plans when admin user is logged in", %{conn: conn} do
      p1 = insert(:plan)
      p2 = insert(:plan)

      conn = get(conn, Routes.v1_plan_path(conn, :index))

      plan_names =
        conn |> json_response(200) |> Enum.map(fn x -> x["name"] end) |> List.to_string()

      plan_descriptions =
        conn |> json_response(200) |> Enum.map(fn x -> x["description"] end) |> List.to_string()

      assert plan_names =~ p1.name
      assert plan_names =~ p2.name
      assert plan_descriptions =~ p1.description
      assert plan_descriptions =~ p2.description
    end

    test "returns all the plans when normal user is logged in", %{conn: conn} do
      p1 = insert(:plan)
      p2 = insert(:plan)

      conn = get(conn, Routes.v1_plan_path(conn, :index))

      plan_names =
        conn |> json_response(200) |> Enum.map(fn x -> x["name"] end) |> List.to_string()

      plan_descriptions =
        conn |> json_response(200) |> Enum.map(fn x -> x["description"] end) |> List.to_string()

      assert plan_names =~ p1.name
      assert plan_names =~ p2.name
      assert plan_descriptions =~ p1.description
      assert plan_descriptions =~ p2.description
    end

    test "returns all the plans when there is no user logged in" do
      conn = build_conn()
      p1 = insert(:plan)
      p2 = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :index))

      plan_names =
        conn |> json_response(200) |> Enum.map(fn x -> x["name"] end) |> List.to_string()

      plan_descriptions =
        conn |> json_response(200) |> Enum.map(fn x -> x["description"] end) |> List.to_string()

      assert plan_names =~ p1.name
      assert plan_names =~ p2.name
      assert plan_descriptions =~ p1.description
      assert plan_descriptions =~ p2.description
    end
  end

  describe "show/2" do
    test "shows a plan on valid uuid when admin user is logged in", %{conn: conn} do
      plan = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :show, plan.id))

      assert json_response(conn, 200)["name"] == plan.name
      assert json_response(conn, 200)["description"] == plan.description
      assert json_response(conn, 200)["yearly_amount"] == plan.yearly_amount
      assert json_response(conn, 200)["monthly_amount"] == plan.monthly_amount
    end

    test "shows a plan on valid uuid when normal user is logged in", %{conn: conn} do
      plan = insert(:plan)

      conn = get(conn, Routes.v1_plan_path(conn, :show, plan.id))

      assert json_response(conn, 200)["name"] == plan.name
      assert json_response(conn, 200)["description"] == plan.description
      assert json_response(conn, 200)["yearly_amount"] == plan.yearly_amount
      assert json_response(conn, 200)["monthly_amount"] == plan.monthly_amount
    end

    test "shows a plan on valid uuid when there is no user logged in" do
      conn = build_conn()
      plan = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :show, plan.id))

      assert json_response(conn, 200)["name"] == plan.name
      assert json_response(conn, 200)["description"] == plan.description
      assert json_response(conn, 200)["yearly_amount"] == plan.yearly_amount
      assert json_response(conn, 200)["monthly_amount"] == plan.monthly_amount
    end

    test "error not found on invalid id" do
      conn = build_conn()
      conn = get(conn, Routes.v1_plan_path(conn, :show, Ecto.UUID.autogenerate()))
      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
    end

    test "returns nil when plan with given uuid does not exist", %{conn: conn} do
      conn = put(conn, Routes.v1_plan_path(conn, :update, Ecto.UUID.generate()), %{name: ""})
      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
    end

    test "returns nil with non UUID value", %{conn: conn} do
      conn = delete(conn, Routes.v1_plan_path(conn, :delete, 1))
      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
    end
  end

  # TODO Can be properly tested only after we decide what router pipelines to use for this action
  #  describe "update/2" do
  #    test "updates plan on valid attributes", %{conn: conn} do
  #      plan = insert(:plan)
  #      conn = put(conn, Routes.v1_plan_path(conn, :update, plan.id), @valid_attrs)
  #
  #      assert json_response(conn, 200)["name"] == @valid_attrs.name
  #      assert json_response(conn, 200)["description"] == @valid_attrs.description
  #      assert json_response(conn, 200)["yearly_amount"] == @valid_attrs.yearly_amount
  #      assert json_response(conn, 200)["monthly_amount"] == @valid_attrs.monthly_amount
  #    end
  #
  #    test "does not update plan and returns error on invalid attributes", %{conn: conn} do
  #      plan = insert(:plan)
  #      conn = put(conn, Routes.v1_plan_path(conn, :update, plan.id), %{name: ""})
  #      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
  #    end
  #
  #    test "returns nil when plan with given uuid does not exist", %{conn: conn} do
  #      conn = put(conn, Routes.v1_plan_path(conn, :update, Ecto.UUID.generate()), %{name: ""})
  #      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
  #    end
  #
  #    test "returns nil with non UUID value", %{conn: conn} do
  #      conn = delete(conn, Routes.v1_plan_path(conn, :delete, 1))
  #      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
  #    end
  #
  #    test "returns error if current user is not admin" do
  #      user = WraftDoc.Factory.insert(:user_with_organisation)
  #      WraftDoc.Factory.insert(:membership, organisation: List.first(user.owned_organisations))
  #
  #      {:ok, token, _} =
  #        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})
  #
  #      conn =
  #        Phoenix.ConnTest.build_conn()
  #        |> Plug.Conn.put_req_header("accept", "application/json")
  #        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
  #        |> Plug.Conn.assign(:current_user, user)
  #
  #      plan = insert(:plan)
  #
  #      conn = put(conn, Routes.v1_plan_path(conn, :update, plan.id), %{})
  #
  #      assert json_response(conn, 401)["errors"] == "You are not authorized for this action.!"
  #    end
  #  end
  # TODO Can be properly tested only after we decide what router pipelines to use for this action
  #  describe "delete/2" do
  #    test "deletes a plan with valid uuid", %{conn: conn} do
  #      plan = insert(:plan)
  #      conn = delete(conn, Routes.v1_plan_path(conn, :delete, plan.id))
  #      assert json_response(conn, 200)["name"] == plan.name
  #      assert json_response(conn, 200)["description"] == plan.description
  #      assert json_response(conn, 200)["yearly_amount"] == plan.yearly_amount
  #      assert json_response(conn, 200)["monthly_amount"] == plan.monthly_amount
  #    end
  #
  #    test "returns nil with non-existent UUID", %{conn: conn} do
  #      conn = delete(conn, Routes.v1_plan_path(conn, :delete, Ecto.UUID.generate()))
  #      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
  #    end
  #
  #    test "returns nil with non UUID value", %{conn: conn} do
  #      conn = delete(conn, Routes.v1_plan_path(conn, :delete, 1))
  #      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
  #    end
  #
  #    test "returns error if current user is not admin" do
  #      user = WraftDoc.Factory.insert(:user_with_organisation)
  #      WraftDoc.Factory.insert(:membership, organisation: List.first(user.owned_organisations))
  #
  #      {:ok, token, _} =
  #        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})
  #
  #      conn =
  #        Phoenix.ConnTest.build_conn()
  #        |> Plug.Conn.put_req_header("accept", "application/json")
  #        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
  #        |> Plug.Conn.assign(:current_user, user)
  #
  #      plan = insert(:plan)
  #
  #      conn = delete(conn, Routes.v1_plan_path(conn, :delete, plan.id))
  #
  #      assert json_response(conn, 401)["errors"] == "You are not authorized for this action.!"
  #    end
  #  end
end
