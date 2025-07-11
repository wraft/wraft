defmodule WraftDoc.Account do
  @moduledoc """
  Module that handles the repo connections of the user context.
  """
  import Ecto.Query
  import Ecto

  alias Ecto.Multi
  alias WraftDoc.Account.Activity
  alias WraftDoc.Account.Profile
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.RoleGroup
  alias WraftDoc.Account.User
  alias WraftDoc.Account.User.Audience
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Assets.Asset
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Blocks.Block
  alias WraftDoc.BlockTemplates.BlockTemplate
  alias WraftDoc.ContentType.ContentType
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.InvitedUsers
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Guardian

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
   Creates a user, generates a personal organisation for the user
   and adds the user to an organisation when the user has an invite token
  """
  @spec registration(map) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def registration(%{"token" => token} = params) do
    {_token_params, user_params} = Map.split(params, ["token"])

    Multi.new()
    |> Multi.run(:get_org, fn _, _ -> get_organisation_and_role_from_token(params) end)
    |> basic_registration_multi(user_params)
    |> Multi.insert(:users_organisations, fn %{user: user, get_org: %{organisation: organisation}} ->
      UserOrganisation.changeset(%UserOrganisation{}, %{
        user_id: user.id,
        organisation_id: organisation.id
      })
    end)
    |> Multi.run(:assign_role, fn _repo, %{user: user, get_org: %{role_ids: role_ids}} ->
      Enterprise.create_default_worker_job(%{user_id: user.id, roles: role_ids}, "assign_role")
    end)
    |> Multi.run(:delete_auth_token, fn _, _ -> AuthTokens.delete_auth_token(token) end)
    |> Repo.transaction()
    |> case do
      {:ok,
       %{
         user: user,
         personal_organisation: %{organisation: personal_org},
         get_org: %{organisation: invited_org}
       }} ->
        update_last_signed_in_org(user, personal_org.id)
        InvitedUsers.create_or_update_invited_user(user.email, invited_org.id, "joined")
        {:ok, %{user: Repo.preload(user, :profile), organisations: [personal_org, invited_org]}}

      {:error, :get_org, :expired, _} ->
        set_invited_user_status_to_expired(token)
        {:error, :expired}

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
        update_last_signed_in_org(user, personal_org.id)
        {:ok, %{user: Repo.preload(user, :profile), organisations: [personal_org]}}

      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  defp basic_registration_multi(multi, params) do
    multi
    |> Multi.insert(:user, User.changeset(%User{}, params),
      on_conflict: {:replace_all_except, [:email]},
      conflict_target: :email
    )
    |> Multi.insert(:profile, fn %{user: user} ->
      user |> build_assoc(:profile) |> Profile.changeset(params)
    end)
    |> Multi.update(:propic, &Profile.propic_changeset(&1.profile, params))
    |> Multi.run(:personal_organisation, fn _repo, %{user: user} ->
      Enterprise.create_personal_organisation(user, %{
        email: params["email"],
        name: "Personal"
      })
    end)
    |> Multi.insert(:user_personal_organisation, fn %{
                                                      user: user,
                                                      personal_organisation: %{organisation: org}
                                                    } ->
      UserOrganisation.changeset(%UserOrganisation{}, %{user_id: user.id, organisation_id: org.id})
    end)
    |> Multi.run(:personal_org_roles, fn _repo,
                                         %{
                                           user: user,
                                           personal_organisation: %{organisation: organisation}
                                         } ->
      Enterprise.create_default_worker_job(
        %{organisation_id: organisation.id, user_id: user.id},
        "personal_organisation_roles"
      )
    end)
    |> Multi.run(:default_flow, fn _repo,
                                   %{
                                     user: user,
                                     personal_organisation: %{organisation: organisation}
                                   } ->
      Enterprise.create_flow(Map.put(user, :current_org_id, organisation.id), %{
        "name" => "Wraft Flow",
        "organisation_id" => organisation.id
      })
    end)
    |> Multi.run(:default_templates, fn _repo,
                                        %{
                                          user: user,
                                          personal_organisation: %{organisation: organisation},
                                          default_flow: flow
                                        } ->
      Enterprise.create_default_worker_job(
        %{
          organisation_id: organisation.id,
          flow_id: flow.id,
          current_user_id: user.id
        },
        "wraft_templates"
      )
    end)
  end

  defp set_invited_user_status_to_expired(token) do
    # Update the invited user status
    {:ok, %{email: email, organisation_id: organisation_id}} =
      AuthTokens.phoenix_token_verify(token, "organisation_invite", max_age: :infinity)

    InvitedUsers.create_or_update_invited_user(email, organisation_id, "expired")
  end

  def show_role(user, id) do
    if role = get_role(user, id), do: Repo.preload(role, [:content_types, :organisation])
  end

  @doc """
    Create new user_role with given user_id and role_id
  """
  def create_user_role(user_id, role_id) do
    %UserRole{}
    |> UserRole.changeset(%{user_id: user_id, role_id: role_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def get_user_role(%{current_org_id: organisation_id}, user_id, role_id) do
    query =
      from(ur in UserRole,
        join: r in Role,
        on: r.id == ur.role_id and r.organisation_id == ^organisation_id,
        where: ur.user_id == ^user_id and ur.role_id == ^role_id
      )

    Repo.one(query)
  end

  @doc """
  Returns a list of users with the given role_id in the current organisation.
  """
  @spec get_role_users(%{current_org_id: Ecto.UUID.t()}, Ecto.UUID.t()) :: [User.t()]
  def get_role_users(%{current_org_id: organisation_id}, role_id) do
    query =
      from(ur in UserRole,
        join: u in User,
        on: u.id == ur.user_id,
        where: ur.role_id == ^role_id and ur.organisation_id == ^organisation_id
      )

    Repo.all(query)
  end

  @doc """
  Returns a list of role IDs for the given user in the current organisation.
  """
  @spec get_user_role_ids(User.t()) :: [Ecto.UUID.t()]
  def get_user_role_ids(%User{id: user_id, current_org_id: organisation_id}) do
    UserRole
    |> join(:inner, [ur], r in Role,
      on: r.id == ur.role_id and r.organisation_id == ^organisation_id
    )
    |> where([ur, r], ur.user_id == ^user_id)
    |> select([ur, r], ur.role_id)
    |> Repo.all()
  end

  @doc """
  Checks if the user is allowed to unassign the given role
  """
  @spec allowed_to_unassign_role?(User.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          boolean() | {:error, String.t()}
  def allowed_to_unassign_role?(%User{current_org_id: org_id}, user_id, role_name) do
    user_role_count = user_roles_count(user_id, org_id)

    cond do
      role_name == "superadmin" && superadmin_users_count(org_id) == 1 ->
        {:error, "Cannot unassign the only superadmin role"}

      user_role_count == 1 ->
        {:error, "Cannot unassign the user's only role"}

      true ->
        true
    end
  end

  @doc """
    Get the number of roles a user has in a given organisation
  """
  @spec user_roles_count(Ecto.UUID.t(), Ecto.UUID.t()) :: integer()
  def user_roles_count(user_id, organisation_id) do
    UserRole
    |> join(:inner, [ur], r in Role,
      on: ur.role_id == r.id and ur.user_id == ^user_id and r.organisation_id == ^organisation_id
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Superadmin users count for the given organisation
  """
  @spec superadmin_users_count(Ecto.UUID.t()) :: integer()
  def superadmin_users_count(organisation_id) do
    UserRole
    |> join(:inner, [ur], r in Role,
      on: ur.role_id == r.id and r.name == "superadmin" and r.organisation_id == ^organisation_id
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
    Deletes the given user_role.
  """
  @spec delete_user_role(UserRole.t()) :: {:ok, UserRole.t()} | nil
  def delete_user_role(user_role), do: Repo.delete(user_role)

  @doc """
  Get a role type from its UUID.
  """
  @spec get_role(Ecto.UUID.t()) :: Role.t() | nil
  def get_role(<<_::288>> = id) do
    Repo.get(Role, id)
  end

  def get_role(_id), do: nil

  @doc """
  Gets a role from its ID and its organisation's ID.
  Accepts either an organisation struct or user struct with
  `current_org_id` key.
  """
  def get_role(%User{current_org_id: org_id}, <<_::288>> = id),
    do: Repo.get_by(Role, id: id, organisation_id: org_id)

  def get_role(%Organisation{id: org_id}, <<_::288>> = id),
    do: Repo.get_by(Role, id: id, organisation_id: org_id)

  def get_role(_, _), do: nil

  @doc """
    Gets a role with its organisation from its ID and its user's ID.

  """
  @spec get_role_with_organisation(%User{current_org_id: integer()}, <<_::288>>) ::
          %Role{} | nil
  def get_role_with_organisation(%User{current_org_id: org_id}, <<_::288>> = id) do
    Role
    |> Repo.get_by(id: id, organisation_id: org_id)
    |> Repo.preload(:organisation)
  end

  def create_role(%User{current_org_id: org_id}, params) do
    params = Map.put(params, "organisation_id", org_id)

    %Role{}
    |> Role.changeset(params)
    |> Repo.insert()
    |> case do
      {:error, _} = changeset -> changeset
      {:ok, role} -> Repo.preload(role, [:organisation])
    end
  end

  @doc """
    Updates a role.
  """
  @spec update_role(User.t(), map) :: Role.t() | Ecto.Changeset.t()
  def update_role(role, params) do
    role
    |> Role.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, role} ->
        Repo.preload(role, [:organisation])

      {:error, _} = changeset ->
        changeset
    end
  end

  def delete_role(role) when role.name != "superadmin" do
    Repo.delete(role)
  end

  def delete_role(_), do: {:error, :no_permission}

  @doc """
  Get the organisation and role from the token, if there is  token in the params.
  """
  @spec get_organisation_and_role_from_token(map) :: Organisation.t() | {:error, atom()}
  def get_organisation_and_role_from_token(%{"token" => token, "email" => email} = _params) do
    with {:ok, %{organisation_id: org_id, email: ^email, roles: role_ids}} <-
           AuthTokens.check_token(token, :invite),
         %Organisation{} = organisation <- Enterprise.get_organisation(org_id),
         [_ | _] = _roles <- Enum.map(role_ids, &get_role(organisation, &1)) do
      {:ok, %{organisation: organisation, role_ids: role_ids}}
    else
      {:ok, _} ->
        {:error, :no_permission}

      nil ->
        {:error, :no_permission}

      [] ->
        {:error, :no_permission}

      error ->
        error
    end
  end

  # This is for test purpose.
  # Should return an error once the product is deployed in production
  def get_organisation_and_role_from_token(_) do
    # Repo.get_by(Organisation, name: "Functionary Labs Pvt Ltd.")
    # {:error, :not_found}
    nil
  end

  @doc """
    Find the user with the given email in wraft
  """
  @spec find(binary()) :: User.t() | {:error, atom}
  def find(email) do
    email
    |> get_user_by_email()
    |> case do
      user = %User{} -> Repo.preload(user, :profile)
      _ -> {:error, :invalid_email}
    end
  end

  @doc """
    Authenticate user and generate token.
  """
  @spec authenticate(%{user: User.t(), password: binary}) ::
          {:error, atom}
          | {:ok, [access_token: Guardian.Token.token(), refresh_token: Guardian.Token.token()]}
  def authenticate(%{user: _, password: password}) when password in ["", nil],
    do: {:error, :no_data}

  def authenticate(%{user: user, password: password}) do
    case Bcrypt.verify_pass(password, user.encrypted_password) do
      true ->
        %{organisation: _personal_org, user: user} =
          Enterprise.get_personal_organisation_and_role(user)

        updated_sign_in_at(user)
        %{user: user, tokens: Guardian.generate_tokens(user, user.last_signed_in_org)}

      _ ->
        {:error, :invalid}
    end
  end

  # Update the recent login time of the user.
  defp updated_sign_in_at(%User{} = user) do
    user
    |> User.update_sign_in_changeset(%{signed_in_at: NaiveDateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
    Update last sign in organisation id of the user
  """
  @spec update_last_signed_in_org(User.t(), Ecto.UUID.t()) :: User.t()
  def update_last_signed_in_org(%User{} = user, <<_::288>> = org_id) do
    user
    |> User.update_last_signed_in_org_changeset(%{last_signed_in_org: org_id})
    |> Repo.update()
  end

  @doc """
    Exchange new pair of tokens for old ones
  """
  @spec refresh_token_exchange(Guardian.Token.token()) ::
          {:error, atom}
          | {:ok, [access_token: Guardian.Token.token(), refresh_token: Guardian.Token.token()]}
  def refresh_token_exchange(refresh_token) do
    with {:ok, _, {access_token, _}} <-
           Guardian.exchange(refresh_token, "refresh", "access", ttl: {2, :hour}),
         {:ok, _, {refresh_token, _}} <-
           Guardian.refresh(refresh_token, ttl: {2, :day}) do
      {:ok, access_token: access_token, refresh_token: refresh_token}
    else
      error ->
        error
    end
  end

  def update_profile(%{id: current_user_id} = current_user, params) do
    profile =
      Profile
      |> Repo.get_by(user_id: current_user_id)
      |> Profile.changeset(params)

    Multi.new()
    |> Multi.update(:profile, profile)
    |> Multi.update(:propic, &Profile.propic_changeset(&1.profile, params))
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
  def get_user(id), do: Repo.get(User, id)

  @doc """
   Get the user from given email and organisation
  """
  @spec get_user_by_email_and_org(Ecto.UUID.t(), binary) :: User.t() | nil
  def get_user_by_email_and_org(organisation_id, email) do
    User
    |> join(:inner, [u], uo in UserOrganisation,
      on: uo.user_id == u.id and uo.organisation_id == ^organisation_id
    )
    |> where([u], u.email == ^email)
    |> Repo.one()
  end

  # Get the user struct from given email
  @spec get_user_by_email(binary) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email(_email), do: nil

  @doc """
  Get the activity stream for current user.
  """

  # TODO - Remove this code
  @spec get_activity_stream(User.t(), map) :: map
  def get_activity_stream(%User{id: id}, params) do
    query =
      from(a in Activity,
        join: au in Audience,
        on: au.user_id == ^id and au.activity_id == a.id,
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
   Enqueue verification email to be sent
  """
  @spec send_email(binary(), AuthToken.t()) :: {:ok, Oban.Job.t()}
  def send_email(email, %AuthToken{} = token) do
    %{email: email, token: token.value}
    |> EmailWorker.new()
    |> Oban.insert()
  end

  @doc """
    Enqueue password set email to be sent
  """
  # TODO- Write tests
  def send_password_set_mail(%AuthToken{} = token) do
    %{email: token.user.email, token: token.value, name: token.user.name}
    |> EmailWorker.new(tags: ["set_password"])
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
  Change/reset the forgotten password, insert the new one and
  delete the password reset token.
  """

  @spec reset_password(map) :: User.t() | {:error, Ecto.Changeset.t()} | {:error, atom}
  def reset_password(%{"token" => token, "password" => _} = params) do
    case AuthTokens.check_token(token, :password_verify) do
      %AuthToken{} = auth_token ->
        User
        |> Repo.get_by(email: auth_token.user.email)
        |> do_update_password(params)
        |> case do
          changeset = {:error, _} ->
            changeset

          %User{} = user_struct ->
            AuthTokens.delete_auth_token!(auth_token)
            user_struct
        end

      changeset = {:error, _} ->
        changeset
    end
  end

  def reset_password(_), do: nil

  @doc """
  Set password for the first time and delete the set password token.
  """
  @spec set_password(String.t(), map) ::
          User.t() | {:error, Ecto.Changeset.t()} | {:error, atom}
  def set_password(
        email,
        %{"password" => password, "confirm_password" => password, "token" => token} = params
      ) do
    User
    |> Repo.get_by(email: email)
    |> do_update_password(params)
    |> case do
      changeset = {:error, _} ->
        changeset

      %User{} = user_struct ->
        AuthTokens.delete_auth_token(token)
        user_struct
    end
  end

  def set_password(_, _), do: {:error, :invalid_password}

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

  def remove_user(%User{current_org_id: organisation_id}, user_id) do
    with %UserOrganisation{user: user} <-
           UserOrganisation
           |> Repo.get_by(user_id: user_id, organisation_id: organisation_id)
           |> Repo.preload(:user) do
      if user.last_signed_in_org == organisation_id do
        personal_org = Repo.get_by(Organisation, creator_id: user_id, name: "Personal")
        update_last_signed_in_org(user, personal_org.id)
      end

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

  # TODO add tests
  def get_user_by_name(current_user, %{"key" => name} = params) do
    User
    |> join(:inner, [u], uo in UserOrganisation, on: uo.user_id == u.id, as: :user_organisation)
    |> where([user_organisation: uo], uo.organisation_id == ^current_user.current_org_id)
    |> where(^dynamic([u], ilike(u.name, ^"%#{name}%")))
    |> preload([:profile])
    |> Repo.paginate(params)
  end

  def get_role_group(%{current_org_id: org_id}, <<_::288>> = id) do
    Repo.get_by(RoleGroup, id: id, organisation_id: org_id)
  end

  def get_role_group(_, _), do: nil

  def show_role_group(user, id) do
    user |> get_role_group(id) |> Repo.preload(:roles)
  end

  def create_role_group(%{current_org_id: org_id}, params) do
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

  # TODO add tests
  @doc """
  Convert UTC time to the given timezone.
  """
  @spec convert_utc_time(NaiveDateTime.t(), String.t()) ::
          NaiveDateTime.t() | {:error, :invalid_datetime}
  def convert_utc_time(datetime, timezone) do
    datetime
    |> DateTime.from_naive("Etc/UTC")
    |> case do
      {:ok, datetime} -> Timex.Timezone.convert(datetime, timezone)
      {:error, _} -> {:error, :invalid_datetime}
    end
  end

  @doc """
  Get or create guest user struct from given email
  """
  @spec get_or_create_guest_user(binary()) :: User.t() | {:error, Ecto.Changeset.t()}
  def get_or_create_guest_user(%{"email" => email} = params) when is_binary(email) do
    case Repo.get_by(User, email: email) do
      nil ->
        create_guest_user(params)

      guest_user ->
        guest_user
    end
  end

  @doc """
  Create a guest user.
  """
  @spec create_guest_user(map()) :: User.t() | Ecto.Changeset.t()
  def create_guest_user(%{"email" => _email} = params) do
    random_password = 8 |> :crypto.strong_rand_bytes() |> Base.encode16() |> binary_part(0, 8)

    params =
      Map.merge(params, %{
        "password" => random_password,
        "is_guest" => true,
        "email_verify" => true
      })

    %User{}
    |> User.guest_user_changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, guest_user} -> guest_user
      {:error, _} = changeset -> changeset
    end
  end
end
