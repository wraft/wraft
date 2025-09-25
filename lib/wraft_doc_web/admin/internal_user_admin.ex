defmodule WraftDocWeb.InternalUserAdmin do
  @moduledoc """
  Admin panel for internal user
  """

  alias WraftDoc.InternalUsers
  alias WraftDoc.InternalUsers.InternalUser

  def index(_) do
    [
      email: %{name: "Email", value: fn x -> x.email end},
      is_deactivated: %{name: "Deactivated", value: fn x -> x.is_deactivated end}
    ]
  end

  def form_fields(_) do
    [
      email: %{label: "Email", update: :readonly},
      password: %{
        label: "Password",
        help_text:
          "Please note down the password so that you can share the credentials with new user."
      },
      is_deactivated: %{label: "is_deactivated", update: :readonly, create: :hidden}
    ]
  end

  def resource_actions(_conn) do
    [
      activate: %{
        name: "Activate",
        action: fn _conn, internal_user ->
          InternalUsers.update_internal_user(internal_user, %{is_deactivated: false})
        end
      },
      deactivate: %{
        name: "Deactivate",
        action: fn _conn, internal_user ->
          InternalUsers.update_internal_user(internal_user, %{is_deactivated: true})
        end
      }
    ]
  end

  def update_changeset(%InternalUser{} = internal_user, attrs) do
    InternalUser.update_changeset(internal_user, attrs)
  end
end
