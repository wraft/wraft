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
    field(:monthly_product_id, :string)
    field(:monthly_amount, :string)
    field(:yearly_product_id, :string)
    field(:yearly_amount, :string)
    field(:type, Ecto.Enum, values: [:free, :regular, :enterprise])
    field(:is_active?, :boolean, default: true)
    field(:custom_price_id, :string)

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
      :monthly_product_id,
      :monthly_amount,
      :yearly_product_id,
      :yearly_amount,
      :organisation_id,
      :custom_price_id,
      :type,
      :features,
      :is_active?
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> cast_embed(:custom)
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      name: :plan_unique_index,
      message: "A plan with the same name exists.!"
    )
  end

  def plan_changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :product_id,
      :monthly_product_id,
      :monthly_amount,
      :features,
      :type,
      :yearly_product_id,
      :yearly_amount,
      :is_active?
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> validate_required([:name, :description, :monthly_amount, :yearly_amount])
    |> unique_constraint(:name,
      name: :plan_unique_index,
      message: "A plan with the same name exists.!"
    )
  end

  def custom_plan_changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :product_id,
      :features,
      :type,
      :organisation_id,
      :custom_price_id
    ])
    |> cast_embed(:limits, with: &Limits.changeset/2, required: true)
    |> cast_embed(:custom, with: &Custom.changeset/2, required: true)
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      name: :plan_unique_index,
      message: "A plan with the same name exists.!"
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
