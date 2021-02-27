defmodule WraftDocWeb.Worker.ScheduledWorker do
  @moduledoc """
  Oban worker for running scheduled jobs.
  """
  use Oban.Worker, queue: :scheduled
  @impl Oban.Worker
  import Ecto.Query
  alias WraftDoc.{Document.Asset, Document.LayoutAsset, Repo}
  alias WraftDoc.{Enterprise, Enterprise.Membership}

  def perform(_args, %{tags: ["unused_assets"]}) do
    IO.puts("Job started..!")

    from(a in Asset,
      left_join: la in LayoutAsset,
      on: la.asset_id == a.id,
      where: is_nil(la.asset_id)
    )
    |> Repo.all()
    |> Stream.map(fn x -> Repo.delete(x) end)
    |> Enum.to_list()

    IO.puts("Job finished..!")
    :ok
  end

  def perform(%{"membership_uuid" => m_uuid}, %{tags: ["plan_expiry"]}) do
    IO.puts("Job started..!")

    with %Membership{end_date: end_date} = membership <- Enterprise.get_membership(m_uuid) do
      Timex.before?(end_date, Timex.now())
      |> case do
        true ->
          membership |> Membership.expired_changeset() |> Repo.update!()

        false ->
          nil
      end

      IO.puts("Job finished..!")
      :ok
    end
  end
end
