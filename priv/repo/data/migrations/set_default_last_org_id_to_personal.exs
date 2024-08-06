defmodule WraftDoc.Repo.Migrations.SetDefaultLastOrgIdToPersonal do
  @moduledoc """
  Script for adding default last org id to personal organisation id for the given user.

  mix run priv/repo/data/migrations/set_default_last_org_id_to_personal.exs
  """
  require Logger
  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  Logger.info("Start default last organisation_id update to personal")

  User
  |> Repo.all()
  |> Enum.each(fn user ->
    personal_org = Repo.get_by(Organisation, creator_id: user.id, name: "Personal")

    Logger.info("Update user #{user.name} last org id to personal: #{inspect(personal_org.id)}")

    Account.update_last_signed_in_org(user, personal_org.id)
  end)

  Logger.info("End default last org id update")
end
