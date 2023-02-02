defmodule WraftDoc.Authorization.Permission do
  @moduledoc false
  use WraftDoc.Schema

  schema "permission" do
    field(:name, :string)
    field(:resource, :string)
    field(:action, :string)
    belongs_to(:role, WraftDoc.Account.Role)
    # TODO to be removed in next ticket
    belongs_to(:resources, WraftDoc.Authorization.Resource)
  end

  def changeset(permission, attrs \\ %{}) do
    permission
    |> cast(attrs, [:name, :resource, :action])
    |> validate_required([:name, :resource, :action])
  end
end
