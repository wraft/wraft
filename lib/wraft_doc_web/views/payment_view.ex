defmodule WraftDocWeb.Api.V1.PaymentView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDocWeb.Api.V1.{MembershipView, OrganisationView, PlanView, UserView}

  def render("payment.json", %{payment: payment}) do
    %{
      id: payment.id,
      razorpay_id: payment.razorpay_id,
      start_date: payment.start_date,
      end_date: payment.end_date,
      invoice_number: payment.invoice_number,
      invoice: generate_url(payment),
      amount: payment.amount,
      action: Payment.get_action(payment),
      status: Payment.get_status(payment),
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
      id: payment.id,
      razorpay_id: payment.razorpay_id,
      start_date: payment.start_date,
      end_date: payment.end_date,
      invoice_number: payment.invoice_number,
      invoice: generate_url(payment),
      amount: payment.amount,
      action: Payment.get_action(payment),
      status: Payment.get_status(payment),
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

  # Convert datetime struct to human readable date format
  defp humanize_date(end_date) do
    Timex.format!(end_date, "%d-%b-%Y", :strftime)
  end

  # Convert datetime struct to human readable datetime format
  defp humanize_time(datetime) do
    Timex.format!(datetime, "%d-%b-%Y %H:%m %P", :strftime)
  end

  # Calculate GST amount from payment amount
  @spec calculate_gst(integer) :: binary()
  defp calculate_gst(amount) do
    gst_in_paisa = 18 * amount / 118
    convert_to_rupee(gst_in_paisa)
  end

  # Calculate plan amount from payment amount
  @spec calculate_plan_amount(integer) :: binary()
  defp calculate_plan_amount(amount) do
    plan_amount_in_paisa = 100 * amount / 118
    convert_to_rupee(plan_amount_in_paisa)
  end

  # Convert paisa to rupee and change float value to binary
  @spec convert_to_rupee(float) :: binary()
  defp convert_to_rupee(paisa) do
    rupee = paisa / 100
    rupee |> Float.round(2) |> :erlang.float_to_binary([{:decimals, 2}])
  end

  defp generate_url(%{invoice: invoice} = payment) do
    WraftDocWeb.InvoiceUploader.url({invoice, payment}, signed: true)
  end
end
