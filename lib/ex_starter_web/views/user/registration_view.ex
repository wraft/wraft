defmodule ExStarterWeb.Api.V1.RegistrationView do
  @moduledoc """
  View module for registration controller.
  """
  use ExStarterWeb, :view
  alias ExStarterWeb.RegistrationView

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
