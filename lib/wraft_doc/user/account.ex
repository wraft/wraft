defmodule WraftDoc.Account do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  import Ecto.Query
  import Ecto

  alias WraftDoc.{
    Account.AuthToken,
    Account.Profile,
    Account.Role,
    Account.User,
    Account.UserRole,
    Enterprise.Organisation,
    Repo
  }

  alias WraftDoc.Document.{
    Asset,
    Block,
    BlockTemplate,
    ContentType,
    ContentTypeField,
    DataTemplate,
    Instance,
    Layout,
    LayoutAsset,
    Theme
  }

  alias WraftDoc.Enterprise.{Flow, Flow.State}

  alias WraftDocWeb.Endpoint

  alias Ecto.Multi

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
    "State" => State,
    "ContentTypeField" => ContentTypeField,
    "LayoutAsset" => LayoutAsset,
    "BlockTemplate" => BlockTemplate
  }

  @doc """
  User Registration
  """
  def change_user do
    User.changeset(%User{})
  end

  @spec registration(map, Organisation.t()) :: User.t() | Ecto.Changeset.t()
  def registration(params, %Organisation{id: id}) do
    params = Map.merge(params, %{"organisation_id" => id})
    role = get_role(params["role"])

    Multi.new()
    |> Multi.insert(:user, User.changeset(%User{}, params))
    |> Multi.insert(:user_role, fn %{user: user} ->
      UserRole.changeset(%UserRole{}, %{user_id: user.id, role_id: role.id})
    end)
    |> Repo.transaction()
    |> case do
      {:error, _, changeset, _} ->
        {:error, changeset}

      {:ok, %{user: %User{} = user}} ->
        create_profile(user, params)
        Repo.preload(user, [:profile, :roles])
    end
  end

  def create_user(params) do
    %User{}
    |> User.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Get the organisation from the token, if there is  token in the params.
  If no token is present in the params, then get the default organisation
  """

  @spec get_organisation_from_token(map) :: Organisation.t()
  def get_organisation_from_token(%{"token" => token, "email" => email} = params) do
    Endpoint
    |> Phoenix.Token.verify("organisation_invite", token, max_age: 900_000)
    |> case do
      {:ok, %{organisation: org, email: token_email, role: role}} ->
        if token_email === email do
          params = Map.put(params, "role", role)
          {:ok, org, params}
        else
          {:error, :no_permission}
        end

      # When token is valid, but encoded data is not what we expected
      {:ok, _} ->
        {:error, :no_permission}

      {:error, :invalid} ->
        {:error, :no_permission}

      {:error, _} = error ->
        error
    end
  end

  # This is for test purpose.
  # Should return an error once the product is deployed in production
  def get_organisation_from_token(_) do
    # Repo.get_by(Organisation, name: "Functionary Labs Pvt Ltd.")
    # {:error, :not_found}
    nil
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
    email
    |> get_user_by_email()
    |> case do
      user = %User{} ->
        user

      _ ->
        {:error, :invalid}
    end
  end

  def admin_find(email) do
    email
    |> get_user_by_email(:super_admin)
    |> case do
      user = %User{} -> user
      _ -> {:error, :invalid}
    end
  end

  @doc """
    Authenticate user and generate token.
  """
  @spec authenticate(%{user: User.t(), password: binary}) ::
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

  @doc """
  Authenticate admin
  """
  def authenticate_admin(%{user: user, password: password}) do
    case Bcrypt.verify_pass(password, user.encrypted_password) do
      true -> user
      _ -> {:error, :invalid_credentials}
    end
  end

  def update_profile(%{id: current_user_id} = current_user, params) do
    profile =
      Profile
      |> Repo.get_by(user_id: current_user_id)
      |> Profile.changeset(params)

    Multi.new()
    |> Multi.update(:profile, profile)
    |> Multi.update(:user, User.update_changeset(current_user, params))
    |> WraftDoc.Repo.transaction()
    |> case do
      {:error, _, changeset, _} ->
        {:error, changeset}

      {:ok, %{profile: profile_struct, user: _user}} ->
        profile_struct
        |> Repo.preload(:user)
        |> Repo.preload(:country)
    end
  end

  @doc """
  Get profile by uuid
  """
  @spec get_profile(Ecto.UUID.t()) :: Profile.t() | nil
  def get_profile(<<_::288>> = id) do
    Profile |> Repo.get_by(uuid: id) |> Repo.preload(:user) |> Repo.preload(:country)
  end

  def get_profile(_id), do: nil

  @doc """
  Delete Profile
  """
  @spec delete_profile(Profile.t()) :: {:ok, Profile.t()} | nil
  def delete_profile(%Profile{} = profile) do
    Repo.delete(profile)
  end

  def delete_profile(_), do: nil

  # Get the role struct from given role name
  @spec get_role(binary) :: Role.t()

  # defp get_role(role \\ "user")

  defp get_role(role) when is_binary(role) do
    Repo.get_by(Role, name: role)
  end

  defp get_role(role) when is_nil(role) do
    Repo.get_by(Role, name: "user")
  end

  @doc """
  Get a role type from its UUID.
  """
  @spec get_role_from_uuid(Ecto.UUID.t()) :: Role.t() | nil
  def get_role_from_uuid(<<_::288>> = uuid) when is_binary(uuid) do
    Repo.get_by(Role, uuid: uuid)
  end

  def get_role_from_uuid(_id), do: nil

  @doc """
  Get a user from its UUID.
  """
  @spec get_user_by_uuid(Ecto.UUID.t()) :: User.t() | nil
  def get_user_by_uuid(<<_::288>> = uuid) when is_binary(uuid) do
    Repo.get_by(User, uuid: uuid)
  end

  def get_user_by_uuid(_), do: nil

  @doc """
  Get a user from its ID.
  """
  @spec get_user(integer() | String.t()) :: User.t() | nil
  def get_user(id) do
    Repo.get(User, id)
  end

  # Get the user struct from given email
  @spec get_user_by_email(binary) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email(_email) do
    nil
  end

  defp get_user_by_email(email, :admin) when is_binary(email) do
    query =
      from(u in User,
        where: u.email == ^email,
        join: r in Role,
        where: r.name == "admin" and r.id == u.role_id
      )

    Repo.one(query)
  end

  defp get_user_by_email(email, :super_admin) when is_binary(email) do
    query =
      from(u in User,
        where: u.email == ^email,
        preload: :roles
      )

    %{roles: roles} = user = Repo.one(query)

    roles
    |> Enum.map(fn x -> x.name end)
    |> Enum.member?("super_admin")
    |> case do
      true -> user
      _ -> nil
    end
  end

  defp get_user_by_email(_email, _) do
    nil
  end

  @doc """
  Get the activity stream for current user.
  """

  # => No test written
  @spec get_activity_stream(User.t(), map) :: map
  def get_activity_stream(%User{id: id}, params) do
    query =
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

    Repo.paginate(query, params)
  end

  @doc """
  Get the actor and object datas of the activity.
  """
  @spec get_activity_datas(list | map) :: list | map
  def get_activity_datas(activities) when is_list(activities) do
    Enum.map(activities, fn x -> get_activity_datas(x) end)
  end

  def get_activity_datas(%{
        action: action,
        actor: actor_id,
        object: object,
        meta: meta,
        inserted_at: inserted_at
      }) do
    actor = get_user(actor_id)
    object_struct = get_activity_object_struct(object)

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
    [model | [id]] = String.split(object, ":")
    Repo.get(@activity_models[model], id)
  end

  defp delete_token(user_id, type) do
    query =
      from(
        a in AuthToken,
        where: a.user_id == ^user_id,
        where: a.token_type == ^type
      )

    query
    |> Repo.all()
    |> Enum.each(fn x -> Repo.delete!(x) end)
  end

  @doc """
  Generate auth token for password reset for the user with the given email ID
  and insert it to auth_tokens table.
  """
  def create_token(%{"email" => email}) do
    email = String.downcase(email)

    case get_user_by_email(email) do
      %User{} = current_user ->
        delete_token(current_user.id, "password_verify")
        token = Endpoint |> Phoenix.Token.sign("reset", current_user.email) |> Base.url_encode64()
        new_params = %{value: token, token_type: "password_verify"}

        {:ok, auth_struct} = insert_auth_token(current_user, new_params)

        Repo.preload(auth_struct, :user)

      nil ->
        {:error, :invalid_email}
    end
  end

  def create_token(_), do: {:error, :invalid_email}

  @doc """
  Validate the password reset link, ie; token in the link to verify and
  authenticate the password reset request.
  """
  def check_token(token) do
    query =
      from(
        tok in AuthToken,
        where: tok.value == ^token,
        where: tok.token_type == "password_verify",
        select: tok
      )

    case Repo.one(query) do
      nil ->
        {:error, :fake}

      token_struct ->
        {:ok, decoded_token} = Base.url_decode64(token_struct.value)

        Endpoint
        |> Phoenix.Token.verify("reset", decoded_token, max_age: 860)
        |> case do
          {:error, :invalid} ->
            {:error, :fake}

          {:error, :expired} ->
            {:error, :expired}

          {:ok, _} ->
            Repo.preload(token_struct, :user)
        end
    end
  end

  @doc """
  Change/reset the forgotten password, insert the new one and
  delete the password reset token.
  """

  @spec reset_password(map) :: User.t() | {:error, Ecto.Changeset.t()} | {:error, atom}
  def reset_password(%{"token" => token, "password" => _} = params) do
    case check_token(token) do
      %AuthToken{} = auth_token ->
        User
        |> Repo.get_by(email: auth_token.user.email)
        |> do_update_password(params)
        |> case do
          changeset = {:error, _} ->
            changeset

          %User{} = user_struct ->
            Repo.delete!(auth_token)
            user_struct
        end

      changeset = {:error, _} ->
        changeset
    end
  end

  def reset_password(_), do: nil

  @doc """
  Update the password of the current user after verifying the
  old password.
  """
  @spec update_password(User.t(), map) :: User.t() | {:error, Ecto.Changeset.t()} | {:error, atom}
  def update_password(user, %{"current_password" => current_password, "password" => _} = params) do
    case Bcrypt.verify_pass(current_password, user.encrypted_password) do
      true ->
        check_and_update_password(user, params)

      _ ->
        {:error, :invalid_password}
    end
  end

  def update_password(_, _), do: nil

  # Update the password if the new one is not same as the previous one.
  @spec check_and_update_password(User.t(), map) ::
          User.t() | {:error, Ecto.Changeset.t()} | {:error, atom}
  defp check_and_update_password(user, %{"password" => password} = params) do
    case Bcrypt.verify_pass(password, user.encrypted_password) do
      true ->
        {:error, :same_password}

      _ ->
        do_update_password(user, params)
    end
  end

  @spec do_update_password(User.t(), map) :: User.t() | {:error, Ecto.Changeset.t()}
  defp do_update_password(user, params) do
    user
    |> User.password_changeset(params)
    |> Repo.update()
    |> case do
      changeset = {:error, _} ->
        changeset

      {:ok, user_struct} ->
        user_struct
    end
  end

  # Insert auth token without expiry date.
  @spec insert_auth_token(User.t() | any(), map) ::
          {:ok, AuthToken.t()} | {:error, Ecto.Changeset.t()} | nil
  defp insert_auth_token(%User{} = current_user, params) do
    current_user
    |> build_assoc(:auth_tokens)
    |> AuthToken.changeset(params)
    |> Repo.insert()
  end

  defp insert_auth_token(_, _), do: nil

  def get_user_by_name(name) do
    user = from(u in User, where: ilike(u.name, ^"%#{name}%"))
    Repo.one(user)
  end
end
