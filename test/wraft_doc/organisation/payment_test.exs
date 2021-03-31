defmodule WraftDoc.Enterprise.Membership.PaymentTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Membership.Payment, Repo}

  @valid_attrs %{
    razorpay_id: "FUNC-001-1",
    start_date: Timex.now(),
    end_date: Timex.shift(Timex.now(), days: 30),
    amount: 1000,
    action: 1,
    status: 1,
    meta: %{id: "FUNC-001-1"}
  }

  @valid_update_attrs %{
    invoice: %Plug.Upload{filename: "invoice.pdf", path: "test/helper/invoice.pdf"},
    invoice_number: "WRAFT_INVOICE-001"
  }

  test "statuses/0 returns a list" do
    statuses = Payment.statuses()

    assert statuses == [failed: 1, captured: 2]
  end

  test "actions/0 returns a list" do
    actions = Payment.actions()

    assert actions == [downgrade: 1, renew: 2, upgrade: 3]
  end

  describe "get_status/1" do
    test "returns a status with valid input" do
      integer = Payment.statuses()[:failed]
      payment = insert(:payment, status: integer)
      string = Payment.get_status(payment)
      assert string == "failed"
    end

    test "returns nil with invalid input" do
      response = Payment.get_status(%{status: 1})
      assert response == nil
    end
  end

  describe "get_action/1" do
    test "returns a action with valid input" do
      integer = Payment.actions()[:downgrade]
      payment = insert(:payment, action: integer)
      string = Payment.get_action(payment)
      assert string == "downgrade"
    end

    test "returns nil with invalid input" do
      response = Payment.get_action(%{action: 1})
      assert response == nil
    end
  end

  describe "changeset/2" do
    test "valid changeset with valid attrs" do
      %{id: org_id} = insert(:organisation)
      %{id: u_id} = insert(:user)
      %{id: m_id} = insert(:membership)
      %{id: fp_id} = insert(:plan)
      %{id: tp_id} = insert(:plan)

      params =
        Map.merge(@valid_attrs, %{
          organisation_id: org_id,
          creator_id: u_id,
          membership_id: m_id,
          from_plan_id: fp_id,
          to_plan_id: tp_id
        })

      changeset = Payment.changeset(%Payment{}, params)
      assert changeset.valid?
    end

    test "invalid changeset with invalid attrs" do
      changeset = Payment.changeset(%Payment{}, %{})
      refute changeset.valid?
    end

    test "razorpay id unique index" do
      insert(:payment, @valid_attrs)
      %{id: org_id} = insert(:organisation)
      %{id: u_id} = insert(:user)
      %{id: m_id} = insert(:membership)
      %{id: fp_id} = insert(:plan)
      %{id: tp_id} = insert(:plan)

      params =
        Map.merge(@valid_attrs, %{
          organisation_id: org_id,
          creator_id: u_id,
          membership_id: m_id,
          from_plan_id: fp_id,
          to_plan_id: tp_id
        })

      {:error, changeset} = %Payment{} |> Payment.changeset(params) |> Repo.insert()
      assert "Something Wrong. Try again.!" in errors_on(changeset, :razorpay_id)
    end
  end

  describe "invoice_changeset/2" do
    test "valid changeset with valid attrs" do
      changeset = Payment.invoice_changeset(%Payment{}, @valid_update_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with invalid attrs" do
      changeset = Payment.invoice_changeset(%Payment{}, %{})
      refute changeset.valid?
    end

    test "invoice number unique index" do
      {_, valid_attrs} = Map.pop!(@valid_update_attrs, :invoice)
      insert(:payment, valid_attrs)
      payment = insert(:payment)

      {:error, changeset} =
        payment |> Payment.invoice_changeset(@valid_update_attrs) |> Repo.update()

      File.rm_rf!("uploads/invoice/#{payment.id}")

      assert "Wrong invoice number.!" in errors_on(changeset, :invoice_number)
    end
  end
end
