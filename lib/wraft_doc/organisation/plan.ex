defmodule WraftDoc.Enterprise.Plan do
  @moduledoc """
  The plan model.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias __MODULE__.Custom
  alias __MODULE__.Limits
  alias WraftDoc.Enterprise.Organisation

  schema "plan" do
    field(:name, :string)
    field(:description, :string)
    field(:features, WraftDocWeb.Kaffy.ArrayField)
    field(:product_id, :string)
    field(:plan_id, :string)
    field(:plan_amount, :string)
    field(:billing_interval, Ecto.Enum, values: [:month, :year, :custom])
    field(:type, Ecto.Enum, values: [:free, :regular, :enterprise])
    field(:is_active?, :boolean, default: true)
    field(:currency, :string, default: "USD")

    belongs_to(:organisation, Organisation)

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
      :is_active?
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> cast_embed(:custom)
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      name: :plans_name_billing_interval_unique_index,
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
      :is_active?
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> validate_required([:name, :description, :plan_amount])
    |> unique_constraint(:name,
      name: :plans_name_billing_interval_unique_index,
      message: "A plan with the same name and billing interval already exists!"
    )
  end

  # TODO custom plan changeset
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
      :organisation_id
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> cast_embed(:custom, with: &Custom.changeset/2, required: true)
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      name: :plans_name_billing_interval_unique_index,
      message: "A plan with the same name and billing interval already exists!"
    )
  end
end

defmodule WraftDoc.Enterprise.Plan.Custom do
  @moduledoc """
  The custom plan model.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @fields [:custom_amount, :custom_period, :custom_period_frequency, :end_date]

  embedded_schema do
    field(:custom_amount, :string)
    field(:custom_period, Ecto.Enum, values: [:day, :week, :month, :year])
    field(:custom_period_frequency, :integer)
    field(:end_date, :utc_datetime)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
  end
end
