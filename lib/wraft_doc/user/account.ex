defmodule WraftDoc.Account do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  # import Ecto.Query, warn: false
  import Ecto
  alias WraftDoc.Repo
  alias WraftDoc.Account.User
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.Profile
  alias WraftDoc.Account.Country

  @doc """
    User Registration
  """
  @spec user_registration(map) :: %Profile{} | Ecto.Changeset.t()
  def user_registration(params \\ %{}) when is_map(params) do
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
            WraftDocWeb.Guardian.encode_and_sign(user)

          _ ->
            {:error, :invalid}
        end
    end
  end

  def update_profile(conn, params) do
    current_user = conn.assigns.current_user.id

    user =
      Profile
      |> Repo.get_by(user_id: current_user)
      |> Profile.changeset(params)

    case Repo.update(user) do
      changeset = {:error, _} ->
        changeset

      {:ok, profile_struct} ->
        Repo.preload(profile_struct, :user)
        |> Repo.preload(:country)
    end
  end
end
