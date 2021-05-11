defmodule WraftDoc.Enterprise.Plan do
  @moduledoc """
  The plan model.
  """
  use WraftDoc.Schema
  alias __MODULE__

  schema "plan" do
    field(:name, :string, null: false)
    field(:description, :string)
    field(:yearly_amount, :integer, default: 0)
    field(:monthly_amount, :integer, default: 0)

    timestamps()

    has_many(:memberships, WraftDoc.Enterprise.Membership)
  end

  def changeset(%Plan{} = plan, attrs \\ %{}) do
    plan
    |> cast(attrs, [:name, :description, :yearly_amount, :monthly_amount])
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      name: :plan_unique_index,
      message: "A plan with the same name exists.!"
    )
  end
end
