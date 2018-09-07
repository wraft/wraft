defmodule StarterWeb.Api.V1.WorkController do
    @moduledoc """
  WorkController module handles the user's work related  
  process.
  """
    use StarterWeb, :controller
    import Ecto.Query, warn: false
    alias Starter.{WorkManagement, WorkManagement.Work, Repo}
require IEx
    action_fallback(StarterWeb.FallbackController)

    #Create Work
    def create(conn, params \\ %{}) do
        with %Work{} = work <- WorkManagement.add_work(conn, params) do
            conn
            |> render("work.json", work: work)
        end   
    end
end