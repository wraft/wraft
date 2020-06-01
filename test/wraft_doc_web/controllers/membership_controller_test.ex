defmodule WraftDocWeb.Api.V1.MembershipControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.{Repo, Enterprise.Membership.Payment}

  @valid_razorpay_id "pay_EvM3nS0jjqQMyK"
  @failed_razorpay_id "pay_EvMEpdcZ5HafEl"

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

  describe "update/2" do
    test "updates membership on valid attributes", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      plan = insert(:plan, yearly_amount: 100_000)
      membership = insert(:membership, organisation: user.organisation)
      attrs = %{plan_id: plan.uuid, razorpay_id: @valid_razorpay_id}
      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.uuid), attrs)

      assert json_response(conn, 200)["id"] == membership.uuid
      assert json_response(conn, 200)["plan_duration"] == 365
      assert json_response(conn, 200)["plan"]["name"] == plan.name
      assert json_response(conn, 200)["plan"]["yearly_amount"] == plan.yearly_amount
    end

    test "does not update membership but creates new payment with failed razorpay id", %{
      conn: conn
    } do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      membership = insert(:membership, organisation: user.organisation)
      plan = insert(:plan)
      attrs = %{plan_id: plan.uuid, razorpay_id: @failed_razorpay_id}
      payment_count = Payment |> Repo.all() |> length
      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.uuid), attrs)

      assert payment_count + 1 == Payment |> Repo.all() |> length
      assert json_response(conn, 400)["info"] == "Payment failed. Membership not updated.!"
    end

    test "does not update membership and returns error with invalid razorpay ID", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      membership = insert(:membership, organisation: user.organisation)
      plan = insert(:plan)
      attrs = %{plan_id: plan.uuid, razorpay_id: "wrong_id"}
      payment_count = Payment |> Repo.all() |> length
      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.uuid), attrs)

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 422)["errors"] == "The id provided does not exist"
    end

    test "does not update membership and returns wrong amount error when razorpay amount does not match any plan amount",
         %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      membership = insert(:membership, organisation: user.organisation)
      plan = insert(:plan, yearly_amount: 1000)
      attrs = %{plan_id: plan.uuid, razorpay_id: @valid_razorpay_id}
      payment_count = Payment |> Repo.all() |> length
      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.uuid), attrs)

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 422)["errors"] == "No plan with paid amount..!!"
    end

    test "returns not found error when membership does not belongs to current user's organisation",
         %{
           conn: conn
         } do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      membership = insert(:membership)
      plan = insert(:plan)
      attrs = %{plan_id: plan.uuid, razorpay_id: @valid_razorpay_id}

      payment_count = Payment |> Repo.all() |> length
      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.uuid), attrs)

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns not found error when plan does not exist ", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      membership = insert(:membership, organisation: user.organisation)
      attrs = %{plan_id: Ecto.UUID.generate(), razorpay_id: @valid_razorpay_id}

      payment_count = Payment |> Repo.all() |> length
      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.uuid), attrs)

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not update membership with wrong parameters", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      membership = insert(:membership, organisation: user.organisation)

      payment_count = Payment |> Repo.all() |> length
      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.uuid), %{})

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 404) == "Not Found"
    end
  end
end
