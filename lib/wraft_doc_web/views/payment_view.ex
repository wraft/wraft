defmodule WraftDocWeb.Api.V1.PaymentView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{OrganisationView, UserView, PlanView, MembershipView}
  alias WraftDoc.Enterprise.Membership.Payment

  def render("payment.json", %{payment: payment}) do
    %{
      id: payment.uuid,
      razorpay_id: payment.razorpay_id,
      start_date: payment.start_date,
      end_date: payment.end_date,
      invoice_number: payment.invoice_number,
      invoice: payment |> generate_url(),
      amount: payment.amount,
      action: payment |> Payment.get_action(),
      status: payment |> Payment.get_status(),
      organisation:
        render_one(payment.organisation, OrganisationView, "organisation.json", as: :organisation),
      creator: render_one(payment.creator, UserView, "user.json", as: :user),
      updated_at: payment.updated_at,
      inserted_at: payment.inserted_at
    }
  end

  def render("index.json", %{
        payments: payments,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      payments: render_many(payments, PaymentView, "payment.json", as: :payment),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{payment: payment}) do
    %{
      id: payment.uuid,
      razorpay_id: payment.razorpay_id,
      start_date: payment.start_date,
      end_date: payment.end_date,
      invoice_number: payment.invoice_number,
      invoice: payment |> generate_url(),
      amount: payment.amount,
      action: payment |> Payment.get_action(),
      status: payment |> Payment.get_status(),
      organisation:
        render_one(payment.organisation, OrganisationView, "organisation.json", as: :organisation),
      creator: render_one(payment.creator, UserView, "user.json", as: :user),
      membership:
        render_one(payment.membership, MembershipView, "only_membership.json", as: :membership),
      from_plan: render_one(payment.from_plan, PlanView, "plan.json", as: :plan),
      to_plan: render_one(payment.to_plan, PlanView, "plan.json", as: :plan),
      updated_at: payment.updated_at,
      inserted_at: payment.inserted_at
    }
  end

  defp generate_url(%{invoice: invoice} = payment) do
    WraftDocWeb.InvoiceUploader.url(invoice, payment)
  end
end
