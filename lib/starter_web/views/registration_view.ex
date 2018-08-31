defmodule StarterWeb.Api.V1.RegistrationView do
  @moduledoc """
  View module for registration controller.
  """
  use StarterWeb, :view
  alias StarterWeb.RegistrationView

  def render("registerview.json", %{user: user}) do
    %{
      firstname: user.firstname,
      lastname: user.lastname,
      mobile: user.mobile,
      email: user.email,
      info: "User Registered.! Welcome to Duruper.!"
    }
  end
end
