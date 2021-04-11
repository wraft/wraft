defmodule WraftDoc.Authorization.Resource do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "resource" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:name, :string)
    field(:category, AtomType)
    field(:action, AtomType)
    has_many(:permissions, WraftDoc.Authorization.Permission)
  end

  def changeset(%Resource{} = resource, attrs \\ %{}) do
    resource
    |> cast(attrs, [:name, :category, :action])
    |> validate_required([:category, :action])
    |> unique_constraint(:category,
      name: :resource_unique_index,
      message: "Action already created under the resource."
    )
  end
end
