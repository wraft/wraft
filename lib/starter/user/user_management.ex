defmodule Starter.User_management do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  # import Ecto.Query, warn: false
  import Ecto
  alias Starter.Repo
  alias Starter.User_management.User
  alias Starter.User_management.Roles
  require IEx
  # User Registration
  def user_registration(params \\ %{}) do
    role =
      Repo.get_by(Roles, name: "user")
      |> build_assoc(:users)
      |> User.changeset(params)
      |> Repo.insert()
  end

  # Fetch user based on email
  def find(email) do
    Repo.get_by(User, email: email)
  end

  # Authenticate user and generate token
  def authenticate(%{user: user, password: password}) do
    case Comeonin.Bcrypt.checkpw(password, user.encrypted_password) do
      true ->
        StarterWeb.Guardian.encode_and_sign(user)

      _ ->
        {:error, :invalid}
    end
  end
end
