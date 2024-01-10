defmodule WraftDocWeb.Api.V1.MembershipControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  import Mox

  alias WraftDoc.Client.RazorpayMock
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDoc.Repo

  @valid_razorpay_id "pay_EvM3nS0jjqQMyK"
  @failed_razorpay_id "pay_EvMEpdcZ5HafEl"
  @invalid_razorpay_error %{
    "code" => "BAD_REQUEST_ERROR",
    "description" => "The id provided does not exist",
    "metadata" => %{},
    "reason" => "input_validation_failed",
    "source" => "business",
    "step" => "payment_initiation"
  }

  describe "show/1" do
    test "shows organisation's membership with valid attrs", %{conn: conn, membership: membership} do
      user = conn.assigns[:current_user]
      conn = get(conn, Routes.v1_membership_path(conn, :show, user.current_org_id))

      assert json_response(conn, 200)["id"] == membership.id
      assert json_response(conn, 200)["plan_duration"] == membership.plan_duration
      assert json_response(conn, 200)["plan"]["name"] == membership.plan.name
      assert json_response(conn, 200)["plan"]["yearly_amount"] == membership.plan.yearly_amount
    end

    test "returns nil when given organisation id is different from user's organisation id", %{
      conn: conn
    } do
      conn = get(conn, Routes.v1_membership_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 400)["errors"] == "The Organisation id does not exist..!"
    end
  end

  describe "update/2" do
    test "updates membership on valid attributes", %{conn: conn, membership: membership} do
      plan = insert(:plan, yearly_amount: 100_000)
      attrs = %{plan_id: plan.id, razorpay_id: @valid_razorpay_id}

      expect(RazorpayMock, :get_payment, fn _ ->
        {:ok,
         %{
           "status" => "captured",
           "amount" => 100_000,
           "id" => @valid_razorpay_id
         }}
      end)

      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.id), attrs)

      assert json_response(conn, 200)["plan_duration"] == 365
      assert json_response(conn, 200)["plan"]["name"] == plan.name
      assert json_response(conn, 200)["plan"]["yearly_amount"] == plan.yearly_amount
    end

    test "does not update membership but creates new payment with failed razorpay id", %{
      conn: conn,
      membership: membership
    } do
      plan = insert(:plan)
      attrs = %{plan_id: plan.id, razorpay_id: @failed_razorpay_id}
      payment_count = Payment |> Repo.all() |> length

      expect(RazorpayMock, :get_payment, fn _ ->
        {:ok,
         %{
           "id" => @failed_razorpay_id,
           "status" => "failed",
           "amount" => 100_000
         }}
      end)

      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.id), attrs)

      assert json_response(conn, 400)["info"] == "Payment failed. Membership not updated.!"
      assert payment_count + 1 == Payment |> Repo.all() |> length
    end

    test "does not update membership and returns error with invalid razorpay ID", %{
      conn: conn,
      membership: membership
    } do
      plan = insert(:plan)
      attrs = %{plan_id: plan.id, razorpay_id: "wrong_id"}
      payment_count = Payment |> Repo.all() |> length

      expect(RazorpayMock, :get_payment, fn _ ->
        {:error, @invalid_razorpay_error}
      end)

      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.id), attrs)
      assert payment_count == Payment |> Repo.all() |> length
      assert @invalid_razorpay_error = json_response(conn, 400)["errors"]
    end

    test "does not update membership and returns wrong amount error when razorpay amount does not match any plan amount",
         %{conn: conn, membership: membership} do
      plan = insert(:plan, yearly_amount: 1000)
      attrs = %{plan_id: plan.id, razorpay_id: @valid_razorpay_id}
      payment_count = Payment |> Repo.all() |> length

      expect(RazorpayMock, :get_payment, fn _ ->
        {:ok,
         %{
           "status" => "captured",
           "amount" => 100_000,
           "id" => @valid_razorpay_id
         }}
      end)

      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.id), attrs)

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 422)["errors"] == "No plan with paid amount..!!"
    end

    test "returns not found error when membership does not belongs to current user's organisation",
         %{
           conn: conn
         } do
      membership = insert(:membership)
      plan = insert(:plan)
      attrs = %{plan_id: plan.id, razorpay_id: @valid_razorpay_id}
      payment_count = Payment |> Repo.all() |> length

      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.id), attrs)

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 404) == "Not Found"
    end

    test "returns not found error when plan does not exist ", %{
      conn: conn,
      membership: membership
    } do
      attrs = %{plan_id: Ecto.UUID.generate(), razorpay_id: @valid_razorpay_id}
      payment_count = Payment |> Repo.all() |> length

      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.id), attrs)

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
    end

    test "does not update membership with wrong parameters", %{conn: conn, membership: membership} do
      payment_count = Payment |> Repo.all() |> length

      conn = put(conn, Routes.v1_membership_path(conn, :update, membership.id), %{})

      assert payment_count == Payment |> Repo.all() |> length
      assert json_response(conn, 400)["errors"] == "The Plan id does not exist..!"
    end
  end
end
