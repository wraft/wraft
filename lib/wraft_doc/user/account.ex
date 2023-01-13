defmodule WraftDoc.Account do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  import Ecto.Query
  import Ecto

  alias Ecto.Multi
  alias WraftDoc.Account.Activity
  alias WraftDoc.Account.AuthToken
  alias WraftDoc.Account.Profile
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.RoleGroup
  alias WraftDoc.Account.User
  alias WraftDoc.Account.User.Audience
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Document.Asset
  alias WraftDoc.Document.Block
  alias WraftDoc.Document.BlockTemplate
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Endpoint

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

  @doc """
   Creates a user, generates a personal organisation for the user
   and adds the user to an organisation when the user has an invite token
  """
  @spec registration(map) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def registration(%{"token" => token} = params) do
    {_token_params, user_params} = Map.split(params, ["token"])

    Multi.new()
    |> Multi.run(:get_org, fn _, _ -> get_organisation_from_token(params) end)
    |> basic_registration_multi(user_params)
    |> Multi.insert(:users_organisations, fn %{user: user, get_org: organisation} ->
      UserOrganisation.changeset(%UserOrganisation{}, %{
        user_id: user.id,
        organisation_id: organisation.id
      })
    end)
    |> Multi.run(:delete_auth_token, fn _, _ -> delete_auth_token(token) end)
    |> Repo.transaction()
    |> case do
      {:ok,
       %{user: user, personal_organisation: %{organisation: personal_org}, get_org: invited_org}} ->
        {:ok, %{user: user, organisations: [personal_org, invited_org]}}

      {:error, :get_org, error, _} ->
        {:error, error}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def registration(params) do
    Multi.new()
    |> basic_registration_multi(params)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, personal_organisation: %{organisation: personal_org}}} ->
        {:ok, %{user: user, organisations: [personal_org]}}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  defp basic_registration_multi(multi, params) do
    multi
    |> Multi.insert(:user, User.changeset(%User{}, params))
    |> Multi.insert(:profile, fn %{user: user} ->
      user |> build_assoc(:profile) |> Profile.changeset(params)
    end)
    |> Multi.run(:personal_organisation, fn _repo, %{user: user} ->
      WraftDoc.Enterprise.create_personal_organisation(user, %{
        email: params["email"],
        name: "Personal"
      })
    end)
  end

  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(params) do
    %User{}
    |> User.changeset(params)
    |> Repo.insert()
  end

  def show_role(user, id) do
    with %Role{} = role <- get_role(user, id) do
      Repo.preload(role, [:content_types, :organisation])
    end
  end

  def get_role(%User{current_org_id: org_id}, <<_::288>> = id) do
    case Repo.get_by(Role, id: id, organisation_id: org_id) do
      %Role{} = role -> role
      _ -> {:error, :invalid_id, "Role"}
    end
  end

  def get_role(%User{current_org_id: _org_id}, _), do: {:error, :invalid_id, "Role"}
  def get_role(_, _), do: {:error, :fake}

  def create_role(%User{current_org_id: org_id}, params) do
    params = Map.put(params, "organisation_id", org_id)

    %Role{}
    |> Role.organisation_changeset(params)
    |> Repo.insert()
    |> case do
      {:error, _} = changeset -> changeset
      {:ok, role} -> Repo.preload(role, [:organisation, :content_types])
    end
  end

  def delete_role(role) do
    Repo.delete(role)
  end

  @doc """
  Get the organisation from the token, if there is  token in the params.
  If no token is present in the params, then get the default organisation
  """
  @spec get_organisation_from_token(map) :: Organisation.t() | {:error, atom()}
  def get_organisation_from_token(%{"token" => token, "email" => email} = _params) do
    case check_token(token, :invite) do
      {:ok, %{organisation_id: org_id, email: ^email, role: _role}} ->
        {:ok, Enterprise.get_organisation(org_id)}

      {:ok, _} ->
        {:error, :no_permission}

      error ->
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
        personal_org = Enterprise.get_personal_org_by_email(user.email)
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: personal_org.id})

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
    Profile |> Repo.get_by(id: id) |> Repo.preload(:user) |> Repo.preload(:country)
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

  # defp get_role(role \\ "user")

  # defp get_role_by_name(role) when is_binary(role) do
  #   Repo.get_by(Role, name: role)
  # end

  # defp get_role_by_name(role) when is_nil(role) do
  #   Repo.get_by(Role, name: "user")
  # end

  @doc """
  Get a role type from its UUID.
  """
  @spec get_role(Ecto.UUID.t()) :: Role.t() | nil
  def get_role(<<_::288>> = id) do
    Repo.get(Role, id)
  end

  def get_role(_id), do: nil

  @doc """
  Get a user from its UUID.
  """
  @spec get_user_by_uuid(Ecto.UUID.t()) :: User.t() | nil
  def get_user_by_uuid(<<_::288>> = id) when is_binary(id) do
    Repo.get(User, id)
  end

  def get_user_by_uuid(_), do: nil

  @doc """
  Get a user from its ID.
  """
  @spec get_user(String.t()) :: User.t() | nil
  def get_user(id) do
    Repo.get(User, id)
  end

  def get_user(<<_::288>> = organisation_id, <<_::288>> = user_id) do
    Repo.get_by(User, id: user_id, organisation_id: organisation_id)
  end

  def get_user(_, _), do: nil

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
      from(a in Activity,
        join: au in Audience,
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

    query
    |> Repo.all()
    |> Enum.map(fn x ->
      actor = get_user(x.actor)
      profile = Repo.get_by!(Profile, user_id: x.actor)

      x
      |> Map.put(:actor, actor)
      |> Map.put(:profile, profile)
    end)
    |> Scrivener.paginate(params)
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

  @doc """
  Deletes a token.
  If an %AuthToken{} is given, it will be deleted.
  If the parameter is a string value, the token is fetched and then deleted.
  Raises if anything goes wrong.
  """
  @spec delete_auth_token!(AuthToken.t() | String.t()) :: AuthToken.t()
  def delete_auth_token!(%AuthToken{} = auth_token) do
    Repo.delete!(auth_token)
  end

  def delete_auth_token(token_value) when is_binary(token_value) do
    AuthToken
    |> Repo.get_by(value: token_value)
    |> case do
      %AuthToken{} = token -> Repo.delete(token)
      nil -> {:error, :invalid}
    end
  end

  @doc """
  Deletes all tokens of given type associated with the user_id.
  """
  @spec delete_auth_token(Ecto.UUID.t(), String.t()) :: {integer(), [AuthToken.t()]}
  def delete_auth_token(user_id, type) do
    query =
      from(
        a in AuthToken,
        where: a.user_id == ^user_id,
        where: a.token_type == ^type
      )

    Repo.delete_all(query)
  end

  @doc """
  Generate auth token for password reset for the user with the given email ID
  and insert it to auth_tokens table.
  """
  def create_password_token(%{"email" => email}) do
    email = String.downcase(email)

    case get_user_by_email(email) do
      %User{} = current_user ->
        delete_auth_token(current_user.id, "password_verify")
        token = WraftDoc.create_phx_token("reset", current_user.email)
        params = %{value: token, token_type: "password_verify"}

        current_user |> insert_auth_token!(params) |> Repo.preload(:user)

      nil ->
        {:error, :invalid_email}
    end
  end

  def create_password_token(_), do: {:error, :invalid_email}

  @doc """
   Create email verification token and send email
  """
  @spec create_token_and_send_email(binary()) :: {:ok, Oban.Job.t()} | {:error, atom()}
  def create_token_and_send_email(email) do
    email
    |> create_email_verification_token()
    |> case do
      {:ok, %AuthToken{} = auth_token} ->
        send_email(email, auth_token)

      {:error, :invalid_email} ->
        {:error, :invalid_email}
        # TODO add logger for testing
    end
  end

  @doc """
  Generate and insert auth_token for email verification
  """
  @spec create_email_verification_token(binary()) :: {:ok, AuthToken.t()} | {:error, atom()}
  def create_email_verification_token(email) do
    case get_user_by_email(email) do
      %User{} = user ->
        token =
          WraftDoc.create_phx_token("email_verification", %{
            email: user.email
          })

        params = %{value: token, token_type: "email_verify"}

        auth_token = insert_auth_token!(user, params)

        {:ok, auth_token}

      nil ->
        {:error, :invalid_email}
    end
  end

  @doc """
   Enqueue verification email to be sent
  """
  @spec send_email(binary(), AuthToken.t()) :: {:ok, Oban.Job.t()}
  def send_email(email, %AuthToken{} = token) do
    %{email: email, token: token.value}
    |> EmailWorker.new()
    |> Oban.insert()
  end

  @doc """
    Enqueue password reset email to be sent
  """
  @spec send_password_reset_mail(AuthToken.t()) :: {:ok, Oban.Job.t()}
  def send_password_reset_mail(%AuthToken{} = token) do
    %{email: token.user.email, token: token.value, name: token.user.name}
    |> EmailWorker.new()
    |> Oban.insert()
  end

  @doc """
     Update email verification status to true for the user
  """
  @spec update_email_status(User.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_email_status(user) do
    changeset = User.email_status_update_changeset(user, %{email_verify: true})
    Repo.update(changeset)
  end

  @doc """
  Validate the phoenix token.
  """
  @spec check_token(String.t(), atom()) :: AuthToken.t() | {:ok, any()} | {:error, atom()}
  def check_token(token, token_type) when token_type == :password_verify do
    case get_auth_token(token, token_type) do
      nil ->
        {:error, :fake}

      token_struct ->
        {:ok, decoded_token} = Base.url_decode64(token_struct.value)

        case phoenix_token_verify(decoded_token, "reset", 860) do
          {:ok, _} ->
            Repo.preload(token_struct, :user)

          error ->
            error
        end
    end
  end

  def check_token(token, token_type) when token_type == :invite do
    case get_auth_token(token, token_type) do
      nil ->
        {:error, :fake}

      token_struct ->
        {:ok, decoded_token} = Base.url_decode64(token_struct.value)

        case phoenix_token_verify(decoded_token, "organisation_invite", 900_000) do
          {:ok, payload} ->
            {:ok, payload}

          {:error, :expired} ->
            {:error, :expired}

          _ ->
            {:error, :fake}
        end
    end
  end

  def check_token(token, token_type) when token_type == :email_verify do
    case get_auth_token(token, token_type) do
      nil ->
        {:error, :fake}

      token_struct ->
        {:ok, decoded_token} = Base.url_decode64(token_struct.value)

        case phoenix_token_verify(decoded_token, "email_verification", 7200) do
          {:ok, payload} ->
            {:ok, payload}

          {:error, :expired} ->
            {:error, :expired}

          _ ->
            {:error, :fake}
        end
    end
  end

  def get_auth_token(token, token_type) do
    query =
      from(
        tok in AuthToken,
        where: tok.value == ^token,
        where: tok.token_type == ^token_type,
        select: tok
      )

    Repo.one(query)
  end

  defp phoenix_token_verify(token, secret, max_age) do
    Endpoint
    |> Phoenix.Token.verify(secret, token, max_age: max_age)
    |> case do
      {:error, :invalid} ->
        {:error, :fake}

      {:error, :expired} ->
        {:error, :expired}

      {:ok, payload} ->
        {:ok, payload}
    end
  end

  @doc """
  Change/reset the forgotten password, insert the new one and
  delete the password reset token.
  """

  @spec reset_password(map) :: User.t() | {:error, Ecto.Changeset.t()} | {:error, atom}
  def reset_password(%{"token" => token, "password" => _} = params) do
    case check_token(token, :password_verify) do
      %AuthToken{} = auth_token ->
        User
        |> Repo.get_by(email: auth_token.user.email)
        |> do_update_password(params)
        |> case do
          changeset = {:error, _} ->
            changeset

          %User{} = user_struct ->
            delete_auth_token!(auth_token)
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

  def update_password(_, _), do: {:error, :no_data}

  def remove_user(%User{current_org_id: org_id}, user_id) do
    with %User{} = user <- get_user(org_id, user_id) do
      user
      |> User.delete_changeset(%{deleted_at: NaiveDateTime.local_now()})
      |> Repo.update()
      |> case do
        {:ok, user} -> user
        {:error, _} = changeset -> changeset
      end
    end
  end

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

  @doc """
  Insert auth token without expiry date.
  """
  @spec insert_auth_token!(User.t() | any(), map) :: AuthToken.t()
  def insert_auth_token!(%User{} = user, params) do
    user
    |> build_assoc(:auth_tokens)
    |> AuthToken.changeset(params)
    |> Repo.insert!()
  end

  def insert_auth_token!(_, _), do: raise("Unexpected arguments passed.")

  @spec insert_auth_token!(map) :: AuthToken.t()
  def insert_auth_token!(params) do
    %AuthToken{}
    |> AuthToken.changeset(params)
    |> Repo.insert()
  end

  def get_user_by_name(name, params) do
    query = from(u in User, where: ilike(u.name, ^"%#{name}%"))
    Repo.paginate(query, params)
  end

  def get_role_group(%{current_org_id: org_id}, <<_::288>> = id) do
    Repo.get_by(RoleGroup, id: id, organisation_id: org_id)
  end

  def get_role_group(_, _), do: nil

  def show_role_group(user, id) do
    user |> get_role_group(id) |> Repo.preload(:roles)
  end

  def create_role_group(%{curent_org_id: org_id}, params) do
    params = Map.put(params, "organisation_id", org_id)

    %RoleGroup{}
    |> RoleGroup.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, role_group} ->
        Repo.preload(role_group, :roles)

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_role_group(_, _), do: nil

  def update_role_group(role_group, params) do
    role_group
    |> RoleGroup.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, role_group} -> Repo.preload(role_group, :roles)
      {:error, _} = changeset -> changeset
    end
  end

  def delete_role_group(role_group) do
    Repo.delete(role_group)
  end

  def list_role_groups(%{current_org_id: org_id}) do
    query = from(rg in RoleGroup, where: rg.organisation_id == ^org_id)
    Repo.all(query)
  end

  def list_role_groups(_), do: nil
end
