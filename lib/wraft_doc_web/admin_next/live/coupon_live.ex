defmodule WraftDocWeb.AdminNext.CouponLive do
  @moduledoc """
  Backpex admin for `WraftDoc.Billing.Coupon`.

  Mirrors `WraftDocWeb.CouponAdmin` (Kaffy):
  - Index columns: name, status, type, code, amount, currency, recurring,
    expiry, creator email.
  - `creator_id` is auto-stamped from the current admin on create.
  - Mutations save via `Coupon.changeset/2` only. The original Kaffy admin
    also called `Billing.create_coupon` / `update_coupon` (Paddle sync); from
    this UI we only persist the row. Paddle sync should be done via the
    existing API/scripts.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.Billing.Coupon,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.create_changeset/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle:
      "Discount codes applied to billing plans. Edits persist locally; sync to Paddle via the API."

  alias WraftDoc.Billing.Coupon

  @impl Backpex.LiveResource
  def singular_name, do: "Coupon"

  @impl Backpex.LiveResource
  def plural_name, do: "Coupons"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{module: Backpex.Fields.Text, label: "Name", searchable: true, orderable: true},
      description: %{module: Backpex.Fields.Textarea, label: "Description"},
      status: %{
        module: Backpex.Fields.Select,
        label: "Status",
        options: [{"Active", :active}, {"Expired", :expired}, {"Archived", :archived}]
      },
      type: %{
        module: Backpex.Fields.Select,
        label: "Type",
        options: [{"Percentage", :percentage}, {"Flat", :flat}]
      },
      coupon_code: %{module: Backpex.Fields.Text, label: "Coupon code", searchable: true},
      amount: %{module: Backpex.Fields.Text, label: "Amount"},
      currency: %{module: Backpex.Fields.Text, label: "Currency"},
      recurring: %{module: Backpex.Fields.Boolean, label: "Recurring"},
      maximum_recurring_intervals: %{
        module: Backpex.Fields.Number,
        label: "Max recurring intervals",
        help_text: "Leave empty for recur-forever"
      },
      usage_limit: %{module: Backpex.Fields.Number, label: "Usage limit"},
      times_used: %{
        module: Backpex.Fields.Number,
        label: "Times used",
        except: [:new, :edit]
      },
      expiry_date: %{
        module: Backpex.Fields.DateTime,
        label: "Expiry",
        help_text: "Leave empty for valid-forever"
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        except: [:new, :edit],
        orderable: true
      }
    ]
  end

  def create_changeset(coupon, attrs, metadata) do
    creator_id =
      case Keyword.get(metadata, :assigns, %{})[:current_admin] do
        %{id: id} -> id
        _ -> nil
      end

    attrs =
      case creator_id do
        nil -> attrs
        id -> Map.put_new(attrs, "creator_id", id)
      end

    Coupon.changeset(coupon, attrs)
  end

  def changeset(coupon, attrs, _metadata) do
    Coupon.changeset(coupon, attrs)
  end
end
