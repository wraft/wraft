defmodule WraftDoc.Authorization.Permission do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "permission" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    belongs_to(:role, WraftDoc.Account.Role)
    belongs_to(:resource, WraftDoc.Authorization.Resource)
  end

  def changeset(%Permission{} = permission, attrs \\ %{}) do
    permission
    |> cast(attrs, [:name, :admin])
    |> validate_required([:name, :admin])
  end
end
