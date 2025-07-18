defmodule WraftDocWeb.PlanAdmin do
  @moduledoc """
  Admin panel for plan module
  """
  import Ecto.Query
  use Ecto.Schema

  alias WraftDoc.Billing
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Repo

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      description: %{name: "Description", value: fn x -> x.description end},
      billing_interval: %{name: "Billing interval", value: fn x -> x.billing_interval end},
      plan_amount: %{name: "Amount", value: fn x -> x.plan_amount end},
      currency: %{name: "Currency"},
      coupon_id: %{
        name: "Coupon",
        value: fn x ->
          if x.coupon do
            Map.get(x.coupon, :coupon_code)
          else
            "No coupon"
          end
        end
      },
      creator: %{
        name: "Creator",
        value: fn x ->
          if x.creator do
            Map.get(x.creator, :email)
          else
            "Nil"
          end
        end
      }
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      description: %{label: "Description", type: :textarea},
      plan_amount: %{label: "Amount"},
      currency: %{
        label: "Currency",
        help_text:
          "Specify the currency to be used. Available currency codes include USD, EUR, GBP, CAD, AUD, NZD, and others supported by Paddle."
      },
      billing_interval: %{
        label: "Billing interval",
        type: :choices,
        choices: [
          {"monthly", :month},
          {"yearly", :year}
        ]
      },
      coupon_id: nil,
      trial_period: %{
        label: "Trial period",
        help_text: "Define trial period with."
      },
      features: %{
        label: "Features"
      },
      limits: %{
        label: "Limits",
        required: true,
        help_text: "Define usage limits for this plan."
      }
    ]
  end

  # def default_actions(_schema) do
  #   [:new, :delete]
  # end

  def ordering(_) do
    [desc: :inserted_at]
  end

  def custom_index_query(_conn, _schema, _query) do
    from(p in Plan,
      where: is_nil(p.custom),
      where: p.is_active? == true,
      preload: [:coupon, :creator]
    )
  end

  def create_changeset(schema, attrs), do: Plan.plan_changeset(schema, attrs)

  def update_changeset(schema, attrs), do: Plan.plan_changeset(schema, attrs)

  def insert(
        %{assigns: %{admin_session: %{id: internal_user_id}}, params: %{"plan" => params}},
        changeset
      ) do
    params
    |> Map.merge(%{"type" => :regular, "creator_id" => internal_user_id})
    |> Enterprise.create_plan()
    |> Billing.handle_response(changeset)
  end

  def update(conn, changeset) do
    params = conn.params["plan"]

    changeset.data
    |> Enterprise.update_plan(params)
    |> Billing.handle_response(changeset)
  end

  def delete(_conn, changeset) do
    changeset
    |> Ecto.Changeset.change(%{is_active?: false})
    |> Repo.update()
    |> Billing.handle_response(changeset)
  end
end
