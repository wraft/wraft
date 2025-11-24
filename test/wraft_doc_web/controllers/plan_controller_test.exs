defmodule WraftDocWeb.Api.V1.PlanControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory

  describe "index/2" do
    test "returns all the plans when admin user is logged in", %{conn: conn} do
      p1 = insert(:plan)
      p2 = insert(:plan)

      conn = get(conn, Routes.v1_plan_path(conn, :index))
      response = json_response(conn, 200)

      plans = response["plans"]

      plan_names = Enum.map(plans, & &1["name"])
      plan_descriptions = Enum.map(plans, & &1["description"])

      assert Enum.any?(plan_names, &(&1 == p1.name))
      assert Enum.any?(plan_names, &(&1 == p2.name))
      assert Enum.any?(plan_descriptions, &(&1 == p1.description))
      assert Enum.any?(plan_descriptions, &(&1 == p2.description))
    end

    test "returns all the plans when normal user is logged in", %{conn: conn} do
      p1 = insert(:plan)
      p2 = insert(:plan)

      conn = get(conn, Routes.v1_plan_path(conn, :index))
      response = json_response(conn, 200)

      plans = response["plans"]

      plan_names = Enum.map(plans, & &1["name"])
      plan_descriptions = Enum.map(plans, & &1["description"])

      assert Enum.any?(plan_names, &(&1 == p1.name))
      assert Enum.any?(plan_names, &(&1 == p2.name))
      assert Enum.any?(plan_descriptions, &(&1 == p1.description))
      assert Enum.any?(plan_descriptions, &(&1 == p2.description))
    end

    test "returns all the plans when there is no user logged in" do
      conn = build_conn()
      p1 = insert(:plan)
      p2 = insert(:plan)

      conn = get(conn, Routes.v1_plan_path(conn, :index))
      response = json_response(conn, 200)

      plans = response["plans"]

      plan_names = Enum.map(plans, & &1["name"])
      plan_descriptions = Enum.map(plans, & &1["description"])

      assert Enum.any?(plan_names, &(&1 == p1.name))
      assert Enum.any?(plan_names, &(&1 == p2.name))
      assert Enum.any?(plan_descriptions, &(&1 == p1.description))
      assert Enum.any?(plan_descriptions, &(&1 == p2.description))
    end
  end

  describe "show/2" do
    test "shows a plan on valid uuid when admin user is logged in", %{conn: conn} do
      plan = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :show, plan.id))

      response = json_response(conn, 200)
      assert response["name"] == plan.name
      assert response["description"] == plan.description
      assert response["plan_amount"] == plan.plan_amount
    end

    test "shows a plan on valid uuid when normal user is logged in", %{conn: conn} do
      plan = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :show, plan.id))

      response = json_response(conn, 200)
      assert response["name"] == plan.name
      assert response["description"] == plan.description
      assert response["plan_amount"] == plan.plan_amount
    end

    test "shows a plan on valid uuid when there is no user logged in" do
      conn = build_conn()
      plan = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :show, plan.id))

      response = json_response(conn, 200)
      assert response["name"] == plan.name
      assert response["description"] == plan.description
      assert response["plan_amount"] == plan.plan_amount
    end

    test "error not found on invalid id" do
      conn = build_conn()
      conn = get(conn, Routes.v1_plan_path(conn, :show, Ecto.UUID.autogenerate()))

      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
    end
  end
end
