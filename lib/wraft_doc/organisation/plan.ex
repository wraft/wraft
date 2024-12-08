defmodule WraftDoc.Enterprise.Plan do
  @moduledoc """
  The plan model.
  """
  use WraftDoc.Schema

  # alias WraftDoc.Billing.Subscription
  alias __MODULE__
  alias __MODULE__.Limits

  schema "plan" do
    field(:name, :string)
    field(:description, :string)
    field(:paddle_product_id, :string)
    field(:monthly_price_id, :string)
    field(:monthly_amount, :string)
    field(:yearly_price_id, :string)
    field(:yearly_amount, :string)

    embeds_one(:limits, Limits)

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
      :yearly_amount
    ])
    |> cast_embed(:limits)
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      name: :plan_unique_index,
      message: "A plan with the same name exists.!"
    )
    |> unique_constraint(:name,
      name: :plan_pkey,
      message: "A plan with the same name exists.!"
    )
  end
end
