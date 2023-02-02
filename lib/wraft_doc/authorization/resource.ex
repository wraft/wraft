defmodule WraftDoc.Authorization.Resource do
  @moduledoc false
  use WraftDoc.Schema
  alias __MODULE__

  schema "resource" do
    field(:name, :string)
    field(:category, AtomType)
    field(:action, AtomType)
    field(:label, :string)
    # has_many(:permissions, WraftDoc.Authorization.Permission)
    # has_many(:roles, through: [:permissions, :role])
  end

  def changeset(%Resource{} = resource, attrs \\ %{}) do
    resource
    |> cast(attrs, [:name, :category, :action, :label])
    |> validate_required([:category, :action])
    |> unique_constraint(:category,
      name: :resource_unique_index,
      message: "Action already created under the resource."
    )
  end
end
