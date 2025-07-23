defmodule WraftDoc.SeedPersonalOrganisations do
  @moduledoc """
  Module for seeding personal organisations for users who don't have them.
  This can be used in migrations or as a standalone task.
  """

  import Ecto.Query
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  @doc """
  Seeds personal organisations for all users who don't have them.
  Returns a tuple with success and error counts.
  """
  @spec seed_all() :: {:ok, %{success: integer(), errors: integer()}}
  def seed_all do
    users_without_personal_org = find_users_without_personal_org()

    IO.puts("Found #{length(users_without_personal_org)} users without personal organisations")

    results = Enum.map(users_without_personal_org, &seed_personal_org_for_user/1)

    success_count = Enum.count(results, &match?(:ok, &1))
    error_count = Enum.count(results, &match?({:error, _}, &1))

    IO.puts("Migration completed. Success: #{success_count}, Errors: #{error_count}")

    {:ok, %{success: success_count, errors: error_count}}
  end

  @doc """
  Seeds personal organisation for a specific user.
  """
  @spec seed_personal_org_for_user(User.t()) :: :ok | {:error, any()}
  def seed_personal_org_for_user(%User{} = user) do
    IO.puts("Creating personal organisation for user: #{user.email}")

    case has_personal_organisation?(user) do
      true ->
        IO.puts("✓ User #{user.email} already has a personal organisation")
        :ok

      false ->
        create_personal_organisation_for_user(user)
    end
  end

  @doc """
  Checks if a user has a personal organisation.
  """
  @spec has_personal_organisation?(User.t()) :: boolean()
  def has_personal_organisation?(%User{id: user_id}) do
    Organisation
    |> where([o], o.creator_id == ^user_id)
    |> where([o], o.name == "Personal")
    |> Repo.exists?()
  end

  @doc """
  Finds all users without personal organisations.
  """
  @spec find_users_without_personal_org() :: [User.t()]
  def find_users_without_personal_org do
    User
    |> join(:left, [u], o in Organisation, on: o.creator_id == u.id and o.name == "Personal")
    |> where([u, o], u.email_verify == true)
    |> where([u, o], is_nil(o.id))
    |> where([u, o], is_nil(u.deleted_at))
    |> select([u, _o], u)
    |> Repo.all()
  end

  defp create_personal_organisation_for_user(%User{} = user) do
    transaction =
      Repo.transaction(fn ->
        {:ok, %{organisation: organisation}} =
          Enterprise.create_personal_organisation(user, %{
            name: "Personal",
            email: user.email
          })

        {:ok, _user_org} =
          %UserOrganisation{}
          |> UserOrganisation.changeset(%{
            user_id: user.id,
            organisation_id: organisation.id
          })
          |> Repo.insert()

        # Create superadmin role for personal organisation
        {:ok, _role} =
          %Role{}
          |> Role.changeset(%{
            name: "superadmin",
            permissions: [],
            organisation_id: organisation.id
          })
          |> Repo.insert()

        if is_nil(user.last_signed_in_org) do
          {:ok, _user} =
            user
            |> Ecto.Changeset.change(%{last_signed_in_org: organisation.id})
            |> Repo.update()
        end

        organisation
      end)

    case transaction do
      {:ok, _organisation} ->
        IO.puts("✓ Created personal organisation for #{user.email}")
        :ok

      {:error, reason} ->
        IO.puts("✗ Failed to create personal organisation for #{user.email}: #{inspect(reason)}")

        {:error, reason}
    end
  end
end
