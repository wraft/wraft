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

  @doc "Render the membership invoice as a self-contained Typst document string."
  @spec invoice_typst(map(), String.t(), Payment.t()) :: String.t()
  def invoice_typst(membership, invoice_number, payment) do
    org = membership.organisation

    date =
      case payment.meta["created_at"] do
        nil -> Timex.format!(DateTime.utc_now(), "{D}/{M}/{YYYY}")
        created_at -> created_at |> Timex.from_unix() |> humanize_time()
      end

    """
    #set page(paper: "a4", margin: 18mm)
    #set text(font: ("DejaVu Sans", "Nimbus Sans"), size: 11pt, fill: rgb("#333333"))

    #let d = (
      invoice_number: "#{typst_escape(invoice_number)}",
      date: "#{typst_escape(date)}",
      legal_name: "#{typst_escape(org.legal_name)}",
      address: "#{typst_escape(org.address)}",
      email: "#{typst_escape(org.email)}",
      plan: "#{typst_escape(membership.plan.description)}",
      plan_amount: "#{typst_escape(calculate_plan_amount(payment.amount))}",
      gst: "#{typst_escape(calculate_gst(payment.amount))}",
      total: "#{typst_escape(convert_to_rupee(payment.amount))}",
      valid_till: "#{typst_escape(humanize_date(payment.end_date))}",
    )

    #grid(columns: (1fr, 1fr),
      align(horizon)[#text(size: 24pt, weight: 800)[Functionary]],
      align(right)[*Invoice No:* #d.invoice_number #linebreak() Date: #d.date],
    )
    #v(8pt)
    #line(length: 100%, stroke: 0.5pt + rgb("#cccccc"))
    #v(12pt)
    #grid(columns: (1fr, 1fr), column-gutter: 24pt,
      [
        *Functionary Labs Pvt Ltd.* #linebreak()
        No. 24, Caravel Building, 1st Main Rd, #linebreak()
        S.T. Bed, Koramangala 4th Block, #linebreak()
        Bengaluru, Karnataka 560095
      ],
      [
        *To:* #linebreak()
        #d.legal_name #linebreak()
        #d.address #linebreak()
        #d.email
      ],
    )
    #v(20pt)
    #table(columns: (1fr, auto), align: (left, right), inset: 8pt,
      fill: (_, row) => if row == 0 { rgb("#333333") },
      table.header(text(fill: white)[*Item*], text(fill: white)[*Price*]),
      [#d.plan], [Rs. #d.plan_amount],
      [18% GST], [Rs. #d.gst],
      [*Total*], [*Rs. #d.total*],
    )
    #v(20pt)
    Your subscription is valid till #d.valid_till.
    #v(36pt)
    #align(center)[For questions/concerns regarding this invoice, please contact #text(fill: rgb("#0071cc"))[#("hello@wraft.co")]]
    #v(10pt)
    #align(center)[#text(weight: 700)[#("www.wraft.co")]]
    """
  end

  # Escape for the Typst string literal so org fields can't inject markup.
  defp typst_escape(value) do
    value
    |> to_string()
    |> String.replace(~r/[\x00-\x1f\x7f]/, " ")
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
