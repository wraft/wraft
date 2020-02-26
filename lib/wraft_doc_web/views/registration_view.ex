defmodule WraftDocWeb.Api.V1.RegistrationView do
  @moduledoc """
  View module for registration controller.
  """
  use WraftDocWeb, :view

  def render("create.json", %{user: user, token: token}) do
    %{
      name: user.name,
      email: user.email,
      email_verify: user.email_verify,
      token: token
    }
  end
end
