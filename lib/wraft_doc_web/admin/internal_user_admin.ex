defmodule WraftDocWeb.InternalUserAdmin do
  @moduledoc """
  Admin panel for internal user
  """
  def index(_) do
    [
      email: %{name: "Email", value: fn x -> x.email end}
    ]
  end

  def form_fields(_) do
    [
      email: %{label: "Email"},
      password: %{
        label: "Password",
        help_text:
          "Please note down the password so that you can share the credentials with new user."
      }
    ]
  end
end
