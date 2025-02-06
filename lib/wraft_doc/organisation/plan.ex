defmodule WraftDoc.Enterprise.Plan do
  @moduledoc """
  The plan model.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias __MODULE__.Custom
  alias __MODULE__.Limits
  alias WraftDoc.Billing.Coupon
  alias WraftDoc.Enterprise.Organisation
  alias WraftDocWeb.Kaffy.ArrayField

  schema "plan" do
    field(:name, :string)
    field(:description, :string)
    field(:features, ArrayField)
    field(:product_id, :string)
    field(:plan_id, :string)
    field(:plan_amount, :string)
    field(:billing_interval, Ecto.Enum, values: [:month, :year, :custom])
    field(:type, Ecto.Enum, values: [:free, :regular, :enterprise])
    field(:is_active?, :boolean, default: true)
    field(:currency, :string, default: "USD")
    field(:pay_link, :string)

    belongs_to(:organisation, Organisation)
    belongs_to(:coupon, Coupon)

    embeds_one(:trial_period, TrialPeriod, on_replace: :delete)
    embeds_one(:limits, Limits, on_replace: :delete)
    embeds_one(:custom, Custom, on_replace: :delete)

    timestamps()
  end

  def changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :product_id,
      :plan_id,
      :plan_amount,
      :billing_interval,
      :organisation_id,
      :type,
      :features,
      :is_active?,
      :pay_link,
      :coupon_id
    ])
    |> validate_plan_amount()
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> cast_embed(:custom)
    |> cast_embed(:trial_period)
    |> validate_required([:name, :description])
    |> unique_constraint([:name, :billing_interval, :is_active?],
      name: :plans_name_billing_interval_active_unique_index,
      message: "A plan with the same name and billing interval already exists!"
    )
  end

  def plan_changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :product_id,
      :plan_id,
      :plan_amount,
      :billing_interval,
      :features,
      :type,
      :is_active?,
      :coupon_id
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> cast_embed(:trial_period)
    |> validate_required([:name, :description, :plan_amount])
    |> validate_plan_amount()
    |> unique_constraint([:name, :billing_interval, :is_active?],
      name: :plans_name_billing_interval_active_unique_index,
      message: "A plan with the same name and billing interval already exists!"
    )
  end

  def custom_plan_changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :product_id,
      :plan_id,
      :billing_interval,
      :features,
      :type,
      :organisation_id,
      :pay_link
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> cast_embed(:custom, with: &Custom.changeset/2, required: true)
    |> cast_embed(:trial_period)
    |> validate_required([:name, :description, :organisation_id])
    |> unique_constraint([:name, :billing_interval, :is_active?],
      name: :plans_name_billing_interval_active_unique_index,
      message: "A plan with the same name and billing interval already exists!"
    )
  end

  defp validate_plan_amount(changeset) do
    case get_change(changeset, :plan_amount) do
      nil ->
        changeset

      amount ->
        case Integer.parse(amount) do
          {num, ""} when num >= 0 ->
            changeset

          _ ->
            add_error(changeset, :plan_amount, "must be 0 or a positive integer")
        end
    end
  end
end

defmodule WraftDoc.Enterprise.Plan.Custom do
  @moduledoc """
  The custom plan model.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @fields [:custom_period, :custom_period_frequency, :end_date]

  embedded_schema do
    field(:custom_period, Ecto.Enum, values: [:day, :week, :month, :year])
    field(:custom_period_frequency, :integer)
    field(:end_date, :utc_datetime)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> validate_number(:custom_period_frequency,
      greater_than: 0,
      message: "Frequency must be a positive integer"
    )
  end
end

defmodule TrialPeriod do
  @moduledoc """
  The trail period model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:period, Ecto.Enum, values: [nil, :day, :week, :month, :year], default: nil)
    field(:frequency, :integer)
  end

  def changeset(trial_period, attrs) do
    trial_period
    |> cast(attrs, [:period, :frequency])
    |> validate_number(:frequency, greater_than: 0)
  end
end
