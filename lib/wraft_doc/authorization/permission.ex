defmodule WraftDoc.Authorization.Permission do
  @moduledoc false
  use WraftDoc.Schema

  schema "permission" do
    field(:name, :string)
    field(:resource, :string)
    field(:action, :string)
  end

  def changeset(permission, attrs \\ %{}) do
    permission
    |> cast(attrs, [:name, :resource, :action])
    |> validate_required([:name, :resource, :action])
    |> unique_constraint(:name,
      message: "permission already exist",
      name: :permission_name_index
    )
    |> unique_constraint(:resource,
      message: "combination of resource and action has to be unique",
      name: :permission_resource_action_index
    )
  end
end
