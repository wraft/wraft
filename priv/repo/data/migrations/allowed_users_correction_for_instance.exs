defmodule WraftDoc.Repo.Migrations.AllowedUsersCorrectionForInstance do
  @moduledoc """
  Script for adding default allowed users for existing document instances

   mix run priv/repo/data/migrations/allowed_users_correction_for_instance.exs
  """
  require Logger
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo

  Logger.info("Starting allowed users update for Instance records")

  Instance
  |> Repo.all()
  |> Enum.each(fn instance ->
    Logger.info("Updating allowed users for instance with id: #{inspect(instance.id)}")

    instance
    |> Ecto.Changeset.change(%{allowed_users: [instance.creator_id]})
    |> Repo.update!()
  end)

  Logger.info("Allowed users update completed")
end
