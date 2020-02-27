defmodule WraftDocWeb.Api.V1.UserView do
  @moduledoc """
  View module for user controller.
  """
  use WraftDocWeb, :view

  def render("sign-in.json", %{token: token, user: user}) do
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
