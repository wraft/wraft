defmodule WraftDocWeb.Worker.ScheduledWorker do
  use Oban.Worker, queue: :scheduled
  @impl Oban.Worker
  import Ecto.Query
  alias WraftDoc.{Repo, Document.Asset, Document.LayoutAsset}
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

{"{\"at\": \"2020-06-03T14:23:06.427125Z\", \"error\": \"** (FunctionClauseError) no function clause matching in WraftDocWeb.Worker.BulkWorker.perform/2\\n\\nThe following arguments were given to WraftDocWeb.Worker.BulkWorker.perform/2:\\n\\n    # 1\\n    %{\\\"membership_uuid\\\" => \\\"8fd799b8-d3e1-499e-ba2e-6ae8cab71a21\\\"}\\n\\n    # 2\\n    %Oban.Job{__meta__: #Ecto.Schema.Metadata<:loaded, \\\"public\\\", \\\"oban_jobs\\\">, args: %{\\\"membership_uuid\\\" => \\\"8fd799b8-d3e1-499e-ba2e-6ae8cab71a21\\\"}, attempt: 1, attempted_at: ~U[2020-06-03 14:23:06.360086Z], attempted_by: [\\\"Shijiths-MacBook-Pro\\\", \\\"default\\\", \\\"5pkpnkck\\\"], completed_at: nil, discarded_at: nil, errors: [], id: 113, inserted_at: ~U[2020-06-03 14:22:06.486625Z], max_attempts: 20, priority: 0, queue: \\\"default\\\", scheduled_at: ~U[2020-06-03 14:23:06.000000Z], state: \\\"executing\\\", tags: [\\\"plan_expiry\\\"], unique: nil, worker: \\\"WraftDocWeb.Worker.BulkWorker\\\"}\\n\\nAttempted function clauses (showing 4 out of 4):\\n\\n    def perform(-%{\\\"user_uuid\\\" => user_uuid, \\\"c_type_uuid\\\" => c_type_uuid, \\\"state_uuid\\\" => state_uuid, \\\"d_temp_uuid\\\" => d_temp_uuid, \\\"mapping\\\" => mapping, \\\"file\\\" => path}-, _job)\\n    def perform(-%{\\\"user_uuid\\\" => user_uuid, \\\"c_type_uuid\\\" => c_type_uuid, \\\"mapping\\\" => mapping, \\\"file\\\" => path}-, _job)\\n    def perform(-%{\\\"user_uuid\\\" => user_uuid, \\\"mapping\\\" => mapping, \\\"file\\\" => path}-, -%{tags: [\\\"block template\\\"]}-)\\n    def perform(trigger, -%{tags: [\\\"pipeline_job\\\"]}-)\\n\\n    (wraft_doc 0.0.1) lib/wraft_doc_web/workers/bulk_worker.ex:7: WraftDocWeb.Worker.BulkWorker.perform/2\\n    (oban 1.2.0) lib/oban/queue/executor.ex:46: Oban.Queue.Executor.perform_inline/2\\n    (oban 1.2.0) lib/oban/queue/executor.ex:18: Oban.Queue.Executor.call/2\\n    (elixir 1.10.2) lib/task/supervised.ex:90: Task.Supervised.invoke_mfa/2\\n    (elixir 1.10.2) lib/task/supervised.ex:35: Task.Supervised.reply/5\\n    (stdlib 3.10) proc_lib.erl:249: :proc_lib.init_p_do_apply/3\\n\", \"attempt\": 1}"}
