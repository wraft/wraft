defmodule ExStarter.UserManagement do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  # import Ecto.Query, warn: false
  import Ecto
  alias ExStarter.Repo
  alias ExStarter.UserManagement.User
  alias ExStarter.UserManagement.Role
  alias ExStarter.ProfileManagement.Profile
  alias ExStarter.ProfileManagement.Country
  require IEx
  # User Registration
  def user_registration(params \\ %{}) do
    country = Repo.get_by(Country, country_code: params["country"])

    role =
      Repo.get_by(Role, name: "user")
      |> build_assoc(:users)
      |> User.changeset(params)

    # To prevent proceeding to next functions if changeset is invalid
    case Repo.insert(role) do
      changeset = {:error, _} ->
        changeset

      _ ->
        # Create profile for the user.    
        {:ok, profile_struct} =
          Repo.get_by(User, email: params["email"])
          |> build_assoc(:basic_profile, country: country)
          |> Profile.changeset(params)
          |> Repo.insert()

        profile =
          profile_struct
          |> Repo.preload(:user)
    end
  end

  # Fetch user based on email
  def find(email) do
    case email do
      "" ->
        {:error, :no_data}

      _ ->
        case Repo.get_by(User, email: email) do
          user = %User{} ->
            user

          _ ->
            {:error, :invalid}
        end
    end
  end

  # Authenticate user and generate token
  def authenticate(%{user: user, password: password}) do
    case password do
      "" ->
        {:error, :no_data}

      _ ->
        case Comeonin.Bcrypt.checkpw(password, user.encrypted_password) do
          true ->
            ExStarterWeb.Guardian.encode_and_sign(user)

          _ ->
            {:error, :invalid}
        end
    end
  end
end
