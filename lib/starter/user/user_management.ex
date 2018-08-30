defmodule Starter.User_management do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  import Ecto.Query, warn: false
  alias Starter.Repo
  alias Starter.User_management.User

# User Registration
  def user_registration(params \\ %{}) do
    %User{}
    |> User.changeset(params)
    |> Repo.insert()
  end
end
