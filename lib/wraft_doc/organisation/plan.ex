defmodule WraftDoc.Enterprise.Plan do
  @moduledoc """
  The plan model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "plan" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:name, :string, null: false)
    field(:description, :string)
    field(:yearly_amount, :integer, default: 0)
    field(:monthly_amount, :integer, default: 0)

    timestamps()
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
