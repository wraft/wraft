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
  end
end
