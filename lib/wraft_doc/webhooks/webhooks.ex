defmodule WraftDoc.Webhooks do
  @moduledoc """
  Context module for managing webhooks in an organization.
  """
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Webhooks.Webhook
  alias WraftDoc.Webhooks.WebhookLog
  alias WraftDoc.Workers.WebhookWorker

  @doc """
  Create a new webhook for an organization.
  """
  @spec create_webhook(User.t(), map()) :: {:ok, Webhook.t()} | {:error, Ecto.Changeset.t()}
  def create_webhook(%User{id: user_id, current_org_id: org_id}, params) do
    params =
      params
      |> Map.put("organisation_id", org_id)
      |> Map.put("creator_id", user_id)

    %Webhook{}
    |> Webhook.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Get a webhook by ID for the current organization.
  """
  @spec get_webhook(User.t(), binary()) :: Webhook.t() | nil
  def get_webhook(%User{current_org_id: org_id}, webhook_id) do
    Repo.get_by(Webhook, id: webhook_id, organisation_id: org_id)
  end

  @doc """
  List all webhooks for the current organization with pagination.
  """
  @spec list_webhooks(User.t(), map()) :: map()
  def list_webhooks(%User{current_org_id: org_id}, params) do
    Webhook
    |> where([w], w.organisation_id == ^org_id)
    |> order_by([w], desc: w.inserted_at)
    |> preload([:creator])
    |> Repo.paginate(params)
  end

  @doc """
  Update a webhook.
  """
  @spec update_webhook(Webhook.t(), map()) :: {:ok, Webhook.t()} | {:error, Ecto.Changeset.t()}
  def update_webhook(%Webhook{} = webhook, params) do
    webhook
    |> Webhook.update_changeset(params)
    |> Repo.update()
  end

  @doc """
  Delete a webhook.
  """
  @spec delete_webhook(Webhook.t()) :: {:ok, Webhook.t()} | {:error, Ecto.Changeset.t()}
  def delete_webhook(%Webhook{} = webhook) do
    Repo.delete(webhook)
  end

  @doc """
  Toggle webhook active status.
  """
  @spec toggle_webhook_status(Webhook.t()) :: {:ok, Webhook.t()} | {:error, Ecto.Changeset.t()}
  def toggle_webhook_status(%Webhook{is_active: is_active} = webhook) do
    update_webhook(webhook, %{is_active: !is_active})
  end

  @doc """
  Trigger webhooks for a specific event and organization.
  """
  @spec trigger_webhooks(binary(), binary(), map()) :: :ok
  def trigger_webhooks(event, organisation_id, payload)
      when is_binary(event) and is_binary(organisation_id) do
    webhooks = get_active_webhooks_for_event(organisation_id, event)

    Enum.each(webhooks, fn webhook ->
      webhook_payload = build_webhook_payload(event, payload, webhook)

      # Queue the webhook for processing
      %{
        webhook_id: webhook.id,
        event: event,
        payload: webhook_payload,
        attempt: 1
      }
      |> WebhookWorker.new(max_attempts: webhook.retry_count + 1)
      |> Oban.insert()
    end)

    :ok
  end

  @doc """
  Get webhooks that should be triggered for a specific event.
  """
  @spec get_active_webhooks_for_event(binary(), binary()) :: [Webhook.t()]
  def get_active_webhooks_for_event(organisation_id, event) do
    Webhook
    |> where([w], w.organisation_id == ^organisation_id)
    |> where([w], w.is_active == true)
    |> where([w], ^event in w.events)
    |> Repo.all()
  end

  @doc """
  Update webhook trigger information after an attempt.
  """
  @spec update_webhook_trigger_info(Webhook.t(), integer(), boolean()) ::
          {:ok, Webhook.t()} | {:error, Ecto.Changeset.t()}
  def update_webhook_trigger_info(%Webhook{} = webhook, status_code, success?) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    failure_count = if success?, do: 0, else: webhook.failure_count + 1

    changeset =
      Webhook.trigger_changeset(webhook, %{
        last_triggered_at: now,
        last_response_status: status_code,
        failure_count: failure_count
      })

    Repo.update(changeset)
  end

  @doc """
  Get available webhook events.
  """
  @spec available_events() :: [binary()]
  def available_events, do: Webhook.webhook_events()

  # Build webhook payload with event data and metadata.
  defp build_webhook_payload(event, data, webhook) do
    timestamp = DateTime.to_iso8601(DateTime.utc_now())

    %{
      event: event,
      timestamp: timestamp,
      webhook_id: webhook.id,
      organisation_id: webhook.organisation_id,
      data: data
    }
  end

  # === Webhook Log Functions ===

  @doc """
  Create a webhook log entry before execution.
  """
  @spec create_webhook_log(map()) :: {:ok, WebhookLog.t()} | {:error, Ecto.Changeset.t()}
  def create_webhook_log(attrs) do
    attrs
    |> WebhookLog.request_changeset()
    |> Repo.insert()
  end

  @doc """
  Update webhook log with response details after execution.
  """
  @spec update_webhook_log(WebhookLog.t(), map()) ::
          {:ok, WebhookLog.t()} | {:error, Ecto.Changeset.t()}
  def update_webhook_log(%WebhookLog{} = webhook_log, attrs) do
    webhook_log
    |> WebhookLog.response_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  List webhook logs for a specific webhook with pagination.
  """
  @spec list_webhook_logs(User.t(), binary(), map()) :: map()
  def list_webhook_logs(%User{current_org_id: org_id}, webhook_id, params) do
    WebhookLog
    |> where([wl], wl.organisation_id == ^org_id and wl.webhook_id == ^webhook_id)
    |> order_by([wl], desc: wl.triggered_at)
    |> preload([:webhook])
    |> Repo.paginate(params)
  end

  @doc """
  List all webhook logs for an organization with pagination and filtering.
  """
  @spec list_all_webhook_logs(User.t(), map()) :: map()
  def list_all_webhook_logs(%User{current_org_id: org_id}, params) do
    query =
      WebhookLog
      |> where([wl], wl.organisation_id == ^org_id)
      |> order_by([wl], desc: wl.triggered_at)
      |> preload([:webhook])

    # Add optional filters
    query = add_log_filters(query, params)

    Repo.paginate(query, params)
  end

  @doc """
  Get a specific webhook log by ID for the current organization.
  """
  @spec get_webhook_log(User.t(), binary()) :: WebhookLog.t() | nil
  def get_webhook_log(%User{current_org_id: org_id}, log_id) do
    WebhookLog
    |> where([wl], wl.organisation_id == ^org_id and wl.id == ^log_id)
    |> preload([:webhook])
    |> Repo.one()
  end

  @doc """
  Get webhook statistics for monitoring.
  """
  @spec get_webhook_stats(User.t(), binary()) :: map()
  def get_webhook_stats(%User{current_org_id: org_id}, webhook_id) do
    # Get stats for the last 30 days
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

    base_query =
      WebhookLog
      |> where([wl], wl.organisation_id == ^org_id and wl.webhook_id == ^webhook_id)
      |> where([wl], wl.triggered_at >= ^thirty_days_ago)

    total_requests = Repo.one(select(base_query, [wl], count(wl.id)))

    successful_requests =
      base_query
      |> where([wl], wl.success == true)
      |> select([wl], count(wl.id))
      |> Repo.one()

    failed_requests = total_requests - successful_requests

    avg_response_time_query =
      base_query
      |> where([wl], wl.success == true and not is_nil(wl.execution_time_ms))
      |> select([wl], avg(wl.execution_time_ms))

    avg_response_time = Repo.one(avg_response_time_query)

    %{
      total_requests: total_requests,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      success_rate:
        if(total_requests > 0, do: successful_requests / total_requests * 100, else: 0),
      average_response_time_ms: avg_response_time || 0,
      period_days: 30
    }
  end

  @doc """
  Delete old webhook logs to manage storage (keeps logs for specified days).
  """
  @spec cleanup_webhook_logs(integer()) :: {integer(), nil}
  def cleanup_webhook_logs(days_to_keep \\ 90) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days_to_keep, :day)

    WebhookLog
    |> where([wl], wl.inserted_at < ^cutoff_date)
    |> Repo.delete_all()
  end

  # Helper function to add filters to webhook logs query
  defp add_log_filters(query, params) do
    query
    |> filter_by_webhook_id(params)
    |> filter_by_event(params)
    |> filter_by_success(params)
    |> filter_by_date_range(params)
  end

  defp filter_by_webhook_id(query, %{"webhook_id" => webhook_id}) when is_binary(webhook_id) do
    where(query, [wl], wl.webhook_id == ^webhook_id)
  end

  defp filter_by_webhook_id(query, _), do: query

  defp filter_by_event(query, %{"event" => event}) when is_binary(event) do
    where(query, [wl], wl.event == ^event)
  end

  defp filter_by_event(query, _), do: query

  defp filter_by_success(query, %{"success" => "true"}),
    do: where(query, [wl], wl.success == true)

  defp filter_by_success(query, %{"success" => "false"}),
    do: where(query, [wl], wl.success == false)

  defp filter_by_success(query, _), do: query

  defp filter_by_date_range(query, %{"from_date" => from_date, "to_date" => to_date}) do
    with {:ok, from_dt, _} <- DateTime.from_iso8601(from_date),
         {:ok, to_dt, _} <- DateTime.from_iso8601(to_date) do
      where(query, [wl], wl.triggered_at >= ^from_dt and wl.triggered_at <= ^to_dt)
    else
      _ -> query
    end
  end

  defp filter_by_date_range(query, _), do: query
end
