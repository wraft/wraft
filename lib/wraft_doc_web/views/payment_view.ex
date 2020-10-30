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

  # Convert datetime struct to human readable date format
  defp humanize_date(end_date) do
    end_date |> Timex.format!("%d-%b-%Y", :strftime)
  end

  # Convert datetime struct to human readable datetime format
  defp humanize_time(datetime) do
    datetime |> Timex.format!("%d-%b-%Y %H:%m %P", :strftime)
  end

  # Calculate GST amount from payment amount
  @spec calculate_gst(integer) :: binary()
  defp calculate_gst(amount) do
    (18 * amount / 118) |> convert_to_rupee
  end

  # Calculate plan amount from payment amount
  @spec calculate_plan_amount(integer) :: binary()
  defp calculate_plan_amount(amount) do
    (100 * amount / 118) |> convert_to_rupee
  end

  # Convert paisa to rupee and change float value to binary
  @spec convert_to_rupee(float) :: binary()
  defp convert_to_rupee(paisa) do
    (paisa / 100) |> Float.round(2) |> :erlang.float_to_binary([{:decimals, 2}])
  end

  defp generate_url(%{invoice: invoice} = payment) do
    WraftDocWeb.InvoiceUploader.url({invoice, payment})
  end
end