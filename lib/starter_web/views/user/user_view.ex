defmodule StarterWeb.Api.V1.UserView do
    @moduledoc """
  View module for user controller.
  """
    use StarterWeb, :view
    
    def render("token.json", %{token: token, user: user}) do
        %{
            token: token,
            user: %{firstname: user.firstname, lastname: user.lastname,
                    email: user.email, mobile: user.mobile}
        }
    end
end