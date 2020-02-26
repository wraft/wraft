defmodule WraftDocWeb.Api.V1.UserView do
  @moduledoc """
  View module for user controller.
  """
  use WraftDocWeb, :view

  def render("sign-in.json", %{token: token, user: user}) do
    %{
      token: token,
      user: %{
        name: user.name,
        email: user.email
      }
    }
  end
end
