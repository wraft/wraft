defmodule WraftDoc.Account.GroupRole do
  @moduledoc """
  Schema for interconnecting role with group
  """

  use WraftDoc.Schema

  schema "group_role" do
    belongs_to(:role, WraftDoc.Account.Role)
    belongs_to(:role_group, WraftDoc.Account.RoleGroup)
    timestamps()
  end
end
