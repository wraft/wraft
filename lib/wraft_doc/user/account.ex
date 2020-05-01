defmodule WraftDoc.Account do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  import Ecto.Query
  import Ecto

  alias WraftDoc.{
    Repo,
    Account.User,
    Account.Role,
    Account.Profile,
    Enterprise.Organisation,
    Account.AuthToken
  }

  alias WraftDocWeb.Endpoint

  alias WraftDoc.Document.{
    Asset,
    Block,
    ContentType,
    ContentTypeField,
    DataTemplate,
    Instance,
    Layout,
    LayoutAsset,
    Theme,
    BlockTemplate
  }

  alias WraftDoc.Enterprise.{Flow, Flow.State}
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
      changeset = {:error, _, _, _} ->
        changeset

      {:ok, %{profile: profile_struct, user: _user}} ->
        Repo.preload(profile_struct, :user)
        |> Repo.preload(:country)
    end
  end

  @doc """
  Get profile by uuid
  """
  @spec get_profile(String.t()) :: Profile.t() | nil
  def get_profile(id) when is_binary(id) do
    Profile |> Repo.get_by(uuid: id) |> Repo.preload(:user) |> Repo.preload(:country)
  end

  def get_profile(_id), do: nil

  @doc """
  Get current profile by Plug.conn
  """
  @spec get_current_profile(Plug.Conn.t()) :: Profile.t()
  def get_current_profile(conn) do
    current_user_id = conn.assigns.current_user.id

    Profile
    |> Repo.get_by(user_id: current_user_id)
    |> Repo.preload(:user)
    |> Repo.preload(:country)
  end

  @doc """
  Delete Profile
  """

  def delete_profile(profile) do
    profile |> Repo.delete()
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
    [model | [id]] = object |> String.split(":")
    @activity_models[model] |> Repo.get(id)
  end

  def delete_token(user_id, type) do
    from(
      a in AuthToken,
      where: a.user_id == ^user_id,
      where: a.token_type == ^type
    )
    |> Repo.all()
    |> Enum.each(fn x -> Repo.delete!(x) end)
  end

  @doc """
  Generate auth token for password reset for the user with the given email ID
  and insert it to auth_tokens table.
  """
  def create_token(%{"email" => email}) do
    email = email |> String.downcase()

    with %User{} = current_user <- Repo.get_by(User, email: email) do
      delete_token(current_user.id, "password_verify")
      token = Phoenix.Token.sign(Endpoint, "reset", current_user.email) |> Base.url_encode64()
      new_params = %{value: token, token_type: "password_verify"}

      {:ok, auth_struct} = insert_auth_token(current_user, new_params)

      auth_struct
      |> Repo.preload(:user)
    else
      nil ->
        {:error, :invalid_email}
    end
  end

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
        {:ok, decoded_token} = token_struct.value |> Base.url_decode64()

        Phoenix.Token.verify(Endpoint, "reset", decoded_token, max_age: 860)
        |> case do
          {:error, :invalid} ->
            {:error, :fake}

          {:error, :expired} ->
            {:error, :expired}

          {:ok, _} ->
            token_struct |> Repo.preload(:user)
        end
    end
  end

  @doc """
  Change/reset the forgotten password, insert the new one and
  delete the password reset token.
  """

  def reset_password(params = %{"token" => token, "password" => _}) do
    with %AuthToken{} = auth_token <- check_token(token) do
      user =
        Repo.get_by(User, email: auth_token.user.email)
        |> User.password_changeset(params)

      case Repo.update(user) do
        changeset = {:error, _} ->
          changeset

        {:ok, user_struct} ->
          Repo.delete!(auth_token)
          user_struct
      end
    else
      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Update the password of the current user after verifying the
  old password.
  """
  def update_password(user, params) do
    case Bcrypt.verify_pass(params["current_password"], user.encrypted_password) do
      true ->
        check_and_update_password(user, params)

      _ ->
        {:error, :invalid_password}
    end
  end

  @doc """
  Update the password if the new one is not same as the previous one.
  """
  def check_and_update_password(user, params) do
    case Bcrypt.verify_pass(params["password"], user.encrypted_password) do
      true ->
        {:error, :same_password}

      _ ->
        do_update_password(user, params)
    end
  end

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

  @doc """
  Insert auth token without expiry date.
  """
  def insert_auth_token(current_user, params) do
    current_user
    |> build_assoc(:auth_tokens)
    |> AuthToken.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Decode and verify the JWT obtained from conn and send an appropriate response.
  To decode and verify the token, Guardian provides a `decode_and_verify` function.
  """
  def verify_jwt_token(headers) do
    with {"authorization", "Bearer " <> token} <-
           headers |> Enum.find(fn {k, _v} -> k == "authorization" end) do
      Guardian.decode_and_verify(WraftDocWeb.Guardian, token)
      |> case do
        {:error, _} ->
          {:error, :token_expired}

        {:ok, _} ->
          {:ok, "verified"}
      end
    else
      nil ->
        {:error, :token_expired}
    end
  end
end
