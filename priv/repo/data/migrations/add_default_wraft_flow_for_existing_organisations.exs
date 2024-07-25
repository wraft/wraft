defmodule WraftDoc.Repo.Migrations.AddDefaultWraftFlowForExistingOrganisations do
  @moduledoc """
  Script for adding default Wraft Flow for existing Organisations.

   mix run priv/repo/data/migrations/add_default_wraft_flow_for_existing_organisations.exs
  """
  require Logger
  alias WraftDoc.Account
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  Logger.info("Starting adding default Wraft Flow for all existing Organisations.")

  Organisation
  |> Repo.all()
  |> Enum.map(fn organisation ->
    Logger.info("Adding default Wraft Flow for existing Organisation: #{organisation.name}")

    current_user = Account.get_user_by_uuid(organisation.creator_id)

    Enterprise.create_flow(Map.put(current_user, :current_org_id, organisation.id), %{
      "name" => "Wraft Flow",
      "organisation_id" => organisation.id
    })

    Logger.info(
      "Finished adding default Wraft Flow for existing Organisation: #{organisation.name}"
    )
  end)

  Logger.info("Finished adding default Wraft Flow for all existing Organisations.")
end
