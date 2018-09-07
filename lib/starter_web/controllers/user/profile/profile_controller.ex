defmodule StarterWeb.Api.V1.ProfileController do
    use StarterWeb, :controller
    import Ecto.Query, warn: false
    alias Starter.{ProfileManagement, ProfileManagement.Profile}
    action_fallback(StarterWeb.FallbackController)
    require IEx
    #Profile Update
    def update(conn, params) do
        with %Profile{} = profile <- ProfileManagement.update_profile(conn, params) do
            conn
            |> render("profile.json", profile: profile)
        end
    end
end