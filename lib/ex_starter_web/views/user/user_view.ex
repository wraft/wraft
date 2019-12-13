defmodule ExStarterWeb.Api.V1.UserView do
  @moduledoc """
  View module for user controller.
  """
  use ExStarterWeb, :view

  def render("token.json", %{token: token, user: user}) do
    %{
      token: token,
      user: %{
        firstname: user.firstname,
        lastname: user.lastname,
        email: user.email,
        mobile: user.mobile
      }
    }
  end

  def render("registerview.json", %{profile: profile}) do
    %{
      firstname: profile.firstname,
      lastname: profile.lastname,
      mobile: profile.user.mobile,
      email: profile.user.email,
      info: "User Registered.! Welcome to Duruper.!"
    }
  end
end
