defmodule WraftDocWeb.PlanAdmin do
  @moduledoc """
  Admin panel for plan module
  """
  import Ecto.Query
  use Ecto.Schema

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
      # TODO: Need to pass when coupon is expired or only pass with no expiry and limit should pass.
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
      preload: [:coupon]
    )
  end

  def create_changeset(schema, attrs) do
    Plan.plan_changeset(schema, attrs)
  end

  def update_changeset(schema, attrs) do
    Plan.plan_changeset(schema, attrs)
  end

  def insert(conn, changeset) do
    conn.params["plan"]
    |> Map.merge(%{"type" => :regular})
    |> Enterprise.create_plan()
    |> handle_repsonse(changeset)
  end

  def update(conn, changeset) do
    params = conn.params["plan"]

    changeset.data
    |> Enterprise.update_plan(params)
    |> handle_repsonse(changeset)
  end

  def delete(_conn, changeset) do
    changeset
    |> Ecto.Changeset.change(%{is_active?: false})
    |> Repo.update()
    |> handle_repsonse(changeset)
  end

  defp handle_repsonse(response, changeset) do
    case response do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end
end
