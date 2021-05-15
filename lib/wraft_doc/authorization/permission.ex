defmodule WraftDoc.Authorization.Permission do
  @moduledoc false
  use WraftDoc.Schema

  schema "permission" do
    belongs_to(:role, WraftDoc.Account.Role)
    belongs_to(:resource, WraftDoc.Authorization.Resource)
  end

  def changeset(permission, attrs \\ %{}) do
    permission
    |> cast(attrs, [:role_id, :resource_id])
    |> unique_constraint(:role_id,
      name: :permission_unique_index,
      message: "Permission already enabled."
    )
  end
end
