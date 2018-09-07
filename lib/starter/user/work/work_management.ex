defmodule Starter.WorkManagement do 
@moduledoc """
    This module handles all the repo connections of the
    Work context
"""

    import Ecto
    alias Starter.Repo
    require IEx
    alias Starter.WorkManagement.Work
    alias Starter.UserManagement.User
    def add_work(conn, params) do
        current_user = conn.assigns.current_user.email
       work = 
        Repo.get_by(User, email: current_user)
        |> build_assoc(:works)
        |> Work.changeset(params)
       case Repo.insert(work) do
           changeset = {:error, _} ->
                changeset 
            {:ok, work_struct} ->
                Repo.preload(work_struct, :user)  
        end
    end
end