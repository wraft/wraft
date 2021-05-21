defmodule WraftDocWeb.Api.V1.PaymentControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory

  setup %{conn: conn} do
    user = insert(:user)

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

  describe "index/2" do
    test "index lists all payments in current user's organisation", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)
      p1 = insert(:payment, organisation: user.organisation)
      p2 = insert(:payment, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = get(conn, Routes.v1_payment_path(conn, :index))

      payments =
        json_response(conn, 200)["payments"]
        |> Enum.map(fn %{"razorpay_id" => r_id} -> r_id end)
        |> List.to_string()

      assert payments =~ p1.razorpay_id
      assert payments =~ p2.razorpay_id
    end
  end

  describe "show/2" do
    test "show renders the payment in the user's organisation with given id", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      payment = insert(:payment, organisation: user.organisation)

      conn = get(conn, Routes.v1_payment_path(conn, :show, payment.id))

      assert json_response(conn, 200)["razorpay_id"] == payment.razorpay_id
      assert json_response(conn, 200)["id"] == payment.id
      assert json_response(conn, 200)["organisation"]["id"] == payment.organisation.id
      assert json_response(conn, 200)["creator"]["id"] == payment.creator.id
      assert json_response(conn, 200)["membership"]["id"] == payment.membership.id
      assert json_response(conn, 200)["from_plan"]["id"] == payment.from_plan.id
      assert json_response(conn, 200)["to_plan"]["id"] == payment.to_plan.id
    end

    test "returns nil when payment does not belong to the user's organisation", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      payment = insert(:payment)
      conn = get(conn, Routes.v1_payment_path(conn, :show, payment.id))
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns nil for non existent payment", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = get(conn, Routes.v1_payment_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns nil for invalid data", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = get(conn, Routes.v1_payment_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 404) == "Not Found"
    end
  end
end
