defmodule WraftDoc.AdminWebhooks do
  @moduledoc """
  Context module for managing system-wide admin webhooks. Admin webhooks are
  triggered exclusively by changes performed through the Kaffy admin panel
  (mounted at `/admin`), and are NOT scoped to an organisation.
  """
  import Ecto.Query

  alias WraftDoc.AdminWebhooks.AdminWebhook
  alias WraftDoc.AdminWebhooks.AdminWebhookLog
  alias WraftDoc.Repo
  alias WraftDoc.Workers.AdminWebhookWorker

  @spec create_admin_webhook(binary() | nil, map()) ::
          {:ok, AdminWebhook.t()} | {:error, Ecto.Changeset.t()}
  def create_admin_webhook(creator_id, params) do
    params = Map.put(params, "creator_id", creator_id)

    %AdminWebhook{}
    |> AdminWebhook.changeset(params)
    |> Repo.insert()
  end

  @spec get_admin_webhook(binary()) :: AdminWebhook.t() | nil
  def get_admin_webhook(id), do: Repo.get(AdminWebhook, id)

  @spec list_admin_webhooks(map()) :: map()
  def list_admin_webhooks(params) do
    AdminWebhook
    |> order_by([w], desc: w.inserted_at)
    |> preload([:creator])
    |> Repo.paginate(params)
  end

  @spec update_admin_webhook(AdminWebhook.t(), map()) ::
          {:ok, AdminWebhook.t()} | {:error, Ecto.Changeset.t()}
  def update_admin_webhook(%AdminWebhook{} = webhook, params) do
    webhook
    |> AdminWebhook.update_changeset(params)
    |> Repo.update()
  end

  @spec delete_admin_webhook(AdminWebhook.t()) ::
          {:ok, AdminWebhook.t()} | {:error, Ecto.Changeset.t()}
  def delete_admin_webhook(%AdminWebhook{} = webhook), do: Repo.delete(webhook)

  @spec toggle_admin_webhook_status(AdminWebhook.t()) ::
          {:ok, AdminWebhook.t()} | {:error, Ecto.Changeset.t()}
  def toggle_admin_webhook_status(%AdminWebhook{is_active: is_active} = webhook) do
    update_admin_webhook(webhook, %{"is_active" => !is_active})
  end

  @doc """
  Enqueue admin webhook delivery jobs for every active subscriber of `event`.
  `actor` is an optional map (e.g. `%{id: ..., email: ...}`) describing the
  internal user that performed the action via /admin.
  """
  @spec trigger_admin_webhooks(binary(), map(), map() | nil) :: :ok
  def trigger_admin_webhooks(event, data, actor \\ nil) when is_binary(event) and is_map(data) do
    event
    |> get_active_admin_webhooks_for_event()
    |> Enum.each(fn webhook ->
      payload = build_payload(event, data, actor, webhook)

      %{
        webhook_id: webhook.id,
        event: event,
        payload: payload,
        attempt: 1
      }
      |> AdminWebhookWorker.new(max_attempts: webhook.retry_count + 1)
      |> Oban.insert()
    end)

    :ok
  end

  @spec get_active_admin_webhooks_for_event(binary()) :: [AdminWebhook.t()]
  def get_active_admin_webhooks_for_event(event) do
    AdminWebhook
    |> where([w], w.is_active == true)
    |> where([w], ^event in w.events)
    |> Repo.all()
  end

  @spec update_admin_webhook_trigger_info(AdminWebhook.t(), integer(), boolean()) ::
          {:ok, AdminWebhook.t()} | {:error, Ecto.Changeset.t()}
  def update_admin_webhook_trigger_info(%AdminWebhook{} = webhook, status_code, success?) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    failure_count = if success?, do: 0, else: webhook.failure_count + 1

    webhook
    |> AdminWebhook.trigger_changeset(%{
      last_triggered_at: now,
      last_response_status: status_code,
      failure_count: failure_count
    })
    |> Repo.update()
  end

  @spec available_events() :: [binary()]
  def available_events, do: AdminWebhook.admin_webhook_events()

  @spec create_admin_webhook_log(map()) ::
          {:ok, AdminWebhookLog.t()} | {:error, Ecto.Changeset.t()}
  def create_admin_webhook_log(attrs) do
    attrs
    |> AdminWebhookLog.request_changeset()
    |> Repo.insert()
  end

  @spec update_admin_webhook_log(AdminWebhookLog.t(), map()) ::
          {:ok, AdminWebhookLog.t()} | {:error, Ecto.Changeset.t()}
  def update_admin_webhook_log(%AdminWebhookLog{} = log, attrs) do
    log
    |> AdminWebhookLog.response_changeset(attrs)
    |> Repo.update()
  end

  defp build_payload(event, data, actor, webhook) do
    %{
      event: event,
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      webhook_id: webhook.id,
      actor: actor,
      data: data
    }
  end
end
