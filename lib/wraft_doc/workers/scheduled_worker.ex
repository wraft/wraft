defmodule WraftDoc.Workers.ScheduledWorker do
  @moduledoc """
  Oban worker for running scheduled jobs.
  """
  use Oban.Worker, queue: :scheduled, tags: ["plan_expiry", "unused_assets"]

  require Logger

  import Ecto.Query

  alias WraftDoc.Assets.Asset
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Membership
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Repo

  @impl Oban.Worker
  def perform(%Job{args: %{"type" => "purge_deleted_records"}}) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

    org_ids_to_check =
      WraftDoc.Account.UserOrganisation
      |> where([r], not is_nil(r.deleted_at) and r.deleted_at < ^cutoff_date)
      |> select([r], r.organisation_id)
      |> Repo.all()

    WraftDoc.Enterprise.Organisation
    |> where([org], org.id in ^org_ids_to_check)
    |> Repo.delete_all()

    Logger.info("Deleted #{length(org_ids_to_check)} organisations")

    :ok
  end

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

  def perform(%Oban.Job{args: %{"plan_id" => plan_id}}) do
    query = from(p in Plan, where: p.id == ^plan_id and p.is_active? == true)
    Repo.update_all(query, set: [is_active?: false])

    :ok
  end
end
