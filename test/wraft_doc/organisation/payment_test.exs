defmodule WraftDoc.Enterprise.Membership.PaymentTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.{Repo, Enterprise.Membership.Payment}

  @valid_attrs %{
    razorpay_id: "FUNC-001-1",
    start_date: Timex.now(),
    end_date: Timex.now() |> Timex.shift(days: 30),
    invoice: %Plug.Upload{filename: "invoice.pdf", path: "test/helper/invoice.pdf"},
    invoice_number: "WRAFT_INVOICE-001",
    amount: 1000,
    action: 1,
    status: 1,
    meta: %{id: "FUNC-001-1"}
  }

  describe "changeset/2" do
    test "valid changeset with valid attrs" do
      %{id: org_id} = insert(:organisation)
      %{id: u_id} = insert(:user)
      %{id: m_id} = insert(:membership)
      %{id: fp_id} = insert(:plan)
      %{id: tp_id} = insert(:plan)

      params =
        @valid_attrs
        |> Map.merge(%{
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
      {_, valid_attrs} = @valid_attrs |> Map.pop!(:invoice)
      insert(:payment, valid_attrs)
      %{id: org_id} = insert(:organisation)
      %{id: u_id} = insert(:user)
      %{id: m_id} = insert(:membership)
      %{id: fp_id} = insert(:plan)
      %{id: tp_id} = insert(:plan)

      params =
        @valid_attrs
        |> Map.merge(%{
          organisation_id: org_id,
          creator_id: u_id,
          membership_id: m_id,
          from_plan_id: fp_id,
          to_plan_id: tp_id
        })

      {:error, changeset} = Payment.changeset(%Payment{}, params) |> Repo.insert()
      assert "Something Wrong. Try again.!" in errors_on(changeset, :razorpay_id)
    end

    test "invoice number unique index" do
      {_, valid_attrs} = @valid_attrs |> Map.pop!(:invoice) |> elem(1) |> Map.pop!(:razorpay_id)
      insert(:payment, valid_attrs)
      %{id: org_id} = insert(:organisation)
      %{id: u_id} = insert(:user)
      %{id: m_id} = insert(:membership)
      %{id: fp_id} = insert(:plan)
      %{id: tp_id} = insert(:plan)

      params =
        @valid_attrs
        |> Map.merge(%{
          organisation_id: org_id,
          creator_id: u_id,
          membership_id: m_id,
          from_plan_id: fp_id,
          to_plan_id: tp_id
        })

      {:error, changeset} = Payment.changeset(%Payment{}, params) |> Repo.insert()
      assert "Wrong invoice number.!" in errors_on(changeset, :invoice_number)
    end
  end
end
