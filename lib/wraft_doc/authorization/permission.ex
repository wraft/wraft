defmodule WraftDoc.Authorization.Permission do
  @moduledoc false
  use WraftDoc.Schema
  alias __MODULE__

  schema "permission" do
    belongs_to(:role, WraftDoc.Account.Role)
    belongs_to(:resource, WraftDoc.Authorization.Resource)
  end

  def changeset(%Permission{} = permission, attrs \\ %{}) do
    permission
    |> cast(attrs, [])
    |> unique_constraint(:role_id,
      name: :permission_unique_index,
      message: "Permission already enabled."
    )
  end
end
