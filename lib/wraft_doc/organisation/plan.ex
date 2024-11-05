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
    field(:yearly_product_id, :string)
    field(:yearly_amount, :string)
    field(:monthly_product_id, :string)
    field(:monthly_amount, :string)

    embeds_one(:limits, Limits)

    # has_many(:subscriptions, Subscription)

    timestamps()
  end

  def changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :yearly_amount,
      :monthly_amount,
      :yearly_product_id,
      :monthly_product_id,
      :limits,
      :subscriptions
    ])
    |> validate_required([:name, :description, :yearly_product_id, :monthly_product_id, :limits])
    |> unique_constraint(:name,
      name: :plan_unique_index,
      message: "A plan with the same name exists.!"
    )
  end
end
