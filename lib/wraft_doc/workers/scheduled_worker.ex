defmodule WraftDoc.Workers.ScheduledWorker do
  @moduledoc """
  Oban worker for running scheduled jobs.
  """
  use Oban.Worker, queue: :scheduled, tags: ["plan_expiry", "unused_assets"]

  require Logger

  import Ecto.Query
  alias WraftDoc.{Document.Asset, Document.LayoutAsset, Repo}
  alias WraftDoc.{Enterprise, Enterprise.Membership}

  @impl Oban.Worker
  def perform(%Job{}) do
    Logger.info("Job started..!")

    query =
      from(a in Asset,
        left_join: la in LayoutAsset,
        on: la.asset_id == a.id,
        where: is_nil(la.asset_id)
      )

    Repo.delete_all(query)

    Logger.info("Job finished..!")
    :ok
  end

  def perform(%Job{args: %{"membership_uuid" => m_uuid}}) do
    Logger.info("Job started..!")

    with %Membership{end_date: end_date} = membership <- Enterprise.get_membership(m_uuid) do
      end_date
      |> Timex.before?(Timex.now())
      |> case do
        true ->
          membership |> Membership.expired_changeset() |> Repo.update!()

        false ->
          nil
      end

      Logger.info("Job finished..!")
      :ok
    end
  end
end
