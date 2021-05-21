defmodule WraftDocWeb.Api.V1.PlanControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory

  @valid_attrs %{
    name: "Basic",
    description: "A free plan, with only basic features",
    yearly_amount: 0,
    monthly_amount: 0
  }

  setup %{conn: conn} do
    role = insert(:role, name: "super_admin")
    user = insert(:user)
    insert(:user_role, role: role, user: user)

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

  describe "create/2" do
    test "creates a plan with valid attrs", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = post(conn, Routes.v1_plan_path(conn, :create), @valid_attrs)
      assert json_response(conn, 200)["name"] == @valid_attrs.name
      assert json_response(conn, 200)["description"] == @valid_attrs.description
      assert json_response(conn, 200)["yearly_amount"] == @valid_attrs.yearly_amount
      assert json_response(conn, 200)["monthly_amount"] == @valid_attrs.monthly_amount
    end

    test "does not create a plan with invalid attrs", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = post(conn, Routes.v1_plan_path(conn, :create), %{})
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
      assert json_response(conn, 422)["errors"]["description"] == ["can't be blank"]
    end

    test "does not create a plan if current user is not an admin" do
      user = insert(:user)

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(
          Routes.v1_user_path(build_conn(), :signin, %{
            email: user.email,
            password: user.password
          })
        )

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)
        |> post(Routes.v1_plan_path(conn, :create), %{})

      assert json_response(conn, 400)["errors"] == "You are not authorized for this action.!"
    end
  end

  describe "index/2" do
    test "returns all the plans when admin user is logged in", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

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

    test "returns all the plans when normal user is logged in" do
      user = insert(:user)

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(
          Routes.v1_user_path(build_conn(), :signin, %{
            email: user.email,
            password: user.password
          })
        )

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

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
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      plan = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :show, plan.id))

      assert json_response(conn, 200)["name"] == plan.name
      assert json_response(conn, 200)["description"] == plan.description
      assert json_response(conn, 200)["yearly_amount"] == plan.yearly_amount
      assert json_response(conn, 200)["monthly_amount"] == plan.monthly_amount
    end

    test "shows a plan on valid uuid when normal user is logged in" do
      user = insert(:user)

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(
          Routes.v1_user_path(build_conn(), :signin, %{
            email: user.email,
            password: user.password
          })
        )

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

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
      plan = insert(:plan)
      conn = get(conn, Routes.v1_plan_path(conn, :show, Ecto.UUID.autogenerate()))
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns nil when plan with given uuid does not exist", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = put(conn, Routes.v1_plan_path(conn, :update, Ecto.UUID.generate()), %{name: ""})
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns nil with non UUID value", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = delete(conn, Routes.v1_plan_path(conn, :delete, 1))
      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "update/2" do
    test "updates plan on valid attributes", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      plan = insert(:plan)
      conn = put(conn, Routes.v1_plan_path(conn, :update, plan.id), @valid_attrs)

      assert json_response(conn, 200)["name"] == @valid_attrs.name
      assert json_response(conn, 200)["description"] == @valid_attrs.description
      assert json_response(conn, 200)["yearly_amount"] == @valid_attrs.yearly_amount
      assert json_response(conn, 200)["monthly_amount"] == @valid_attrs.monthly_amount
    end

    test "does not update plan and returns error on invalid attributes", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      plan = insert(:plan)
      conn = put(conn, Routes.v1_plan_path(conn, :update, plan.id), %{name: ""})
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end

    test "returns nil when plan with given uuid does not exist", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = put(conn, Routes.v1_plan_path(conn, :update, Ecto.UUID.generate()), %{name: ""})
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns nil with non UUID value", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = delete(conn, Routes.v1_plan_path(conn, :delete, 1))
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns error if current user is not admin" do
      user = insert(:user)
      plan = insert(:plan)

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(
          Routes.v1_user_path(build_conn(), :signin, %{
            email: user.email,
            password: user.password
          })
        )

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)
        |> put(Routes.v1_plan_path(conn, :update, plan.id), %{})

      assert json_response(conn, 400)["errors"] == "You are not authorized for this action.!"
    end
  end

  describe "delete/2" do
    test "deletes a plan with valid uuid", %{conn: conn} do
      plan = insert(:plan)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = delete(conn, Routes.v1_plan_path(conn, :delete, plan.id))
      assert json_response(conn, 200)["name"] == plan.name
      assert json_response(conn, 200)["description"] == plan.description
      assert json_response(conn, 200)["yearly_amount"] == plan.yearly_amount
      assert json_response(conn, 200)["monthly_amount"] == plan.monthly_amount
    end

    test "returns nil with non-existent UUID", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = delete(conn, Routes.v1_plan_path(conn, :delete, Ecto.UUID.generate()))
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns nil with non UUID value", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = delete(conn, Routes.v1_plan_path(conn, :delete, 1))
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns error if current user is not admin" do
      user = insert(:user)
      plan = insert(:plan)

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(
          Routes.v1_user_path(build_conn(), :signin, %{
            email: user.email,
            password: user.password
          })
        )

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)
        |> delete(Routes.v1_plan_path(conn, :delete, plan.id))

      assert json_response(conn, 400)["errors"] == "You are not authorized for this action.!"
    end
  end
end
