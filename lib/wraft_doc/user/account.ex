defmodule WraftDoc.Account do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  import Ecto.Query
  import Ecto
  alias WraftDoc.{Repo, Account.User, Account.Role, Account.Profile, Enterprise.Organisation}
  alias WraftDoc.Document.{Asset, Block, ContentType, DataTemplate, Instance, Layout, Theme}
  alias WraftDoc.Enterprise.{Flow, Flow.State}

  @activity_models %{
    "Asset" => Asset,
    "Block" => Block,
    "ContentType" => ContentType,
    "DataTemplate" => DataTemplate,
    "Instance" => Instance,
    "Instance-State" => Instance,
    "Layout" => Layout,
    "Theme" => Theme,
    "Flow" => Flow,
    "State" => State
  }

  @doc """
    User Registration
  """
  @spec registration(map, Organisation.t()) :: User.t() | Ecto.Changeset.t()
  def registration(params, %Organisation{id: id}) do
    params = params |> Map.merge(%{"organisation_id" => id})

    get_role()
    |> build_assoc(:users)
    |> User.changeset(params)
    |> Repo.insert()
    |> case do
      changeset = {:error, _} ->
        changeset

      {:ok, %User{} = user} ->
        create_profile(user, params)
        user |> Repo.preload(:profile)
    end
  end

  @doc """
  Get the organisation from the token, if there is  token in the params.
  If no token is present in the params, then get the default organisation
  """
  @spec get_organisation_from_token(map) :: Organisation.t()
  def get_organisation_from_token(%{"token" => token, "email" => email}) do
    Phoenix.Token.verify(WraftDocWeb.Endpoint, "organisation_invite", token, max_age: 9_00_000)
    |> case do
      {:ok, %{organisation: org, email: token_email}} ->
        cond do
          token_email == email ->
            org

          true ->
            {:error, :no_permission}
        end

      {:error, :invalid} ->
        {:error, :no_permission}

      {:error, _} = error ->
        error
    end
  end

  def get_organisation_from_token(_) do
    Repo.get_by(Organisation, name: "Functionary Labs Pvt Ltd.")
  end

  @doc """
    Create profile for the user
  """
  @spec create_profile(User.t(), map) :: {atom, Profile.t()}
  def create_profile(user, params) do
    user
    |> build_assoc(:profile)
    |> Profile.changeset(params)
    |> Repo.insert()
  end

  @doc """
    Find the user with the given email
  """
  @spec find(binary()) :: User.t() | {:error, atom}
  def find(email) do
    get_user_by_email(email)
    |> case do
      user = %User{} ->
        user

      _ ->
        {:error, :invalid}
    end
  end

  @doc """
    Authenticate user and generate token.
  """
  @spec authenticate(%{user: User.t(), password: binary | nil}) ::
          {:error, atom} | {:ok, Guardian.Token.token(), Guardian.Token.claims()}
  def authenticate(%{user: _, password: ""}), do: {:error, :no_data}
  def authenticate(%{user: _, password: nil}), do: {:error, :no_data}

  def authenticate(%{user: user, password: password}) do
    case Bcrypt.verify_pass(password, user.encrypted_password) do
      true ->
        WraftDocWeb.Guardian.encode_and_sign(user)

      _ ->
        {:error, :invalid}
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

  # Get the role struct from given role name
  @spec get_role(binary) :: Role.t()
  defp get_role(role \\ "user")

  defp get_role(role) when is_binary(role) do
    Repo.get_by(Role, name: role)
  end

  @doc """
  Get a role type from its UUID.
  """
  @spec get_role_from_uuid(binary) :: Role.t()
  def get_role_from_uuid(uuid) do
    Repo.get_by(Role, uuid: uuid)
  end

  @doc """
  Get a user from its UUID.
  """
  def get_user_by_uuid(uuid) do
    Repo.get_by(User, uuid: uuid)
  end

  @spec get_user(integer() | String.t()) :: User.t() | nil
  defp get_user(id) do
    Repo.get(User, id)
  end

  # Get the user struct from given email
  @spec get_user_by_email(binary) :: User.t() | nil
  defp get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  defp get_user_by_email(_email) do
    nil
  end

  @doc """
  Get the activity stream for current user.
  """
  @spec get_activity_stream(User.t(), map) :: map
  def get_activity_stream(%User{id: id}, params) do
    from(a in Spur.Activity,
      join: au in "audience",
      where: au.user_id == ^id and au.activity_id == a.id,
      order_by: [desc: a.inserted_at],
      select: %{
        action: a.action,
        actor: a.actor,
        object: a.object,
        meta: a.meta,
        inserted_at: a.inserted_at
      }
    )
    |> Repo.paginate(params)
  end

  @doc """
  Get the actor and object datas of the activity.
  """
  @spec get_activity_datas(list | map) :: list | map
  def get_activity_datas(activities) when is_list(activities) do
    activities |> Enum.map(fn x -> get_activity_datas(x) end)
  end

  def get_activity_datas(%{
        action: action,
        actor: actor_id,
        object: object,
        meta: meta,
        inserted_at: inserted_at
      }) do
    actor = actor_id |> get_user()
    object_struct = object |> get_activity_object_struct()

    %{
      action: action,
      actor: actor,
      object: object,
      object_struct: object_struct,
      meta: meta,
      inserted_at: inserted_at
    }
  end

  @spec get_activity_object_struct(String.t()) :: map | nil
  defp get_activity_object_struct(object) do
    [model | [id]] = object |> String.split(":")
    @activity_models[model] |> Repo.get(id)
  end
end
