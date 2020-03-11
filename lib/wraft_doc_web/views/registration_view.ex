defmodule WraftDocWeb.Api.V1.RegistrationView do
  @moduledoc """
  View module for registration controller.
  """
  use WraftDocWeb, :view

  def render("create.json", %{user: user, token: token}) do
    %{
      token: token,
      user: %{
        id: user.uuid,
        name: user.name,
        email: user.email,
        email_verify: user.email_verify,
        inserted_at: user.inserted_at,
        updated_at: user.updated_at
      }
    }
  end
end
