defmodule WraftDocWeb.Api.V1.PaymentViewTest do
  use WraftDoc.DataCase, async: true

  alias WraftDocWeb.Api.V1.PaymentView

  describe "invoice_typst/3" do
    setup do
      membership = %{
        organisation: %{
          legal_name: "Acme Corp",
          address: "12 Market St, Bengaluru",
          email: "billing@acme.io"
        },
        plan: %{description: "Pro Plan (annual)"}
      }

      payment = %{amount: 590_000, end_date: ~U[2027-06-23 00:00:00Z], meta: %{}}
      %{membership: membership, payment: payment}
    end

    test "renders a Typst document with the invoice number, plan and computed amounts", ctx do
      typ = PaymentView.invoice_typst(ctx.membership, "WraftDoc-Invoice-000042", ctx.payment)

      assert typ =~ "#set page"
      assert typ =~ "WraftDoc-Invoice-000042"
      assert typ =~ "Pro Plan (annual)"
      # 590000 paisa -> plan 5000.00, 18% GST 900.00, total 5900.00
      assert typ =~ "5000.00"
      assert typ =~ "900.00"
      assert typ =~ "5900.00"
    end

    test "escapes a quote-bearing organisation name so it cannot inject Typst markup", ctx do
      membership = ctx.membership

      membership =
        put_in(membership.organisation.legal_name, "Acme \" + read(\"/etc/passwd\") + \" Ltd")

      typ = PaymentView.invoice_typst(membership, "INV-1", ctx.payment)

      # Quote escaped inside the string literal -- no raw breakout.
      assert typ =~ ~S|legal_name: "Acme \" + read(\"/etc/passwd\") + \" Ltd"|
      refute typ =~ ~S|legal_name: "Acme " + read|
    end
  end
end
