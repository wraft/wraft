defmodule StarterWeb.Api.V1.ProfileController do
    use StarterWeb, :controller
    import Ecto.Query, warn: false
    alias Starter.{ProfileManagement}
    action_fallback(StarterWeb.FallbackController)
    require IEx
    #Profile Update
    def update(conn, params) do
        # IEx.pry
        # with {:ok, %Profile{} = profile} <- ProfileManagement.update_profile(params)
        ProfileManagement.update_profile(conn, params)     
    end
end