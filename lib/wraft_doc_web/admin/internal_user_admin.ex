defmodule WraftDocWeb.InternalUserAdmin do
  @moduledoc """
  Admin panel for internal user
  """

  alias WraftDoc.InternalUsers.InternalUser

  def index(_) do
    [
      email: %{name: "Email", value: fn x -> x.email end},
      is_deactivated: %{name: "Deactivated", value: fn x -> x.is_deactivated end}
    ]
  end

  def form_fields(_) do
    [
      email: %{label: "Email"},
      password: %{
        label: "Password",
        help_text:
          "Please note down the password so that you can share the credentials with new user."
      },
      is_deactivated: %{label: "is_deactivated"}
    ]
  end

  def update_changeset(%InternalUser{} = internal_user, attrs) do
    InternalUser.update_changeset(internal_user, attrs)
  end
end
