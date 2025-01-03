defmodule WraftDoc.Enterprise.Plan do
  @moduledoc """
  The plan model.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias __MODULE__.Custom
  alias __MODULE__.Limits

  schema "plan" do
    field(:name, :string)
    field(:description, :string)
    field(:paddle_product_id, :string)
    field(:monthly_price_id, :string)
    field(:monthly_amount, :string)
    field(:yearly_price_id, :string)
    field(:yearly_amount, :string)
    field(:custom_price_id, :string)

    embeds_one(:custom, Custom, on_replace: :delete)
    embeds_one(:limits, Limits, on_replace: :delete)

    timestamps()
  end

  def changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :paddle_product_id,
      :monthly_price_id,
      :monthly_amount,
      :yearly_price_id,
      :yearly_amount,
      :custom_price_id
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
      :paddle_product_id,
      :monthly_price_id,
      :monthly_amount,
      :yearly_price_id,
      :yearly_amount
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
      :paddle_product_id,
      :custom_price_id
    ])
    |> cast_embed(:limits, required: true)
    |> cast_embed(:custom, required: true)
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
  @fields [:custom_amount, :custom_period, :custom_period_frequency]

  embedded_schema do
    field(:custom_amount, :string)
    field(:custom_period, Ecto.Enum, values: [:day, :week, :month, :year])
    field(:custom_period_frequency, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
  end
end
