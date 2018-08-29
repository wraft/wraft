defmodule StarterWeb.Api.V1.RegistrationView do
    use StarterWeb, :view
    alias StarterWeb.RegistrationView

    def render("registerview.json", %{user: user}) do
        %{
            name: user.name,
            email: user.email,
            info: "User Registered.! Welcome to Duruper.!"
        }
    end
end