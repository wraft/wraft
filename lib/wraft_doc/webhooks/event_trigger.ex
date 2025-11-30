defmodule WraftDoc.Webhooks.EventTrigger do
  @moduledoc """
  Module for triggering webhook events based on document state changes.
  """
  require Logger

  alias WraftDoc.Documents.Instance
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Webhooks

  @doc """
  Trigger document.created event when a new document instance is created.
  """
  @spec trigger_document_created(Instance.t()) :: :ok
  def trigger_document_created(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "created")
    Webhooks.trigger_webhooks("document.created", org_id, payload)
    Logger.info("Triggered document.created webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.sent event when a document is sent for approval.
  """
  @spec trigger_document_sent(Instance.t()) :: :ok
  def trigger_document_sent(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "sent")
    Webhooks.trigger_webhooks("document.sent", org_id, payload)
    Logger.info("Triggered document.sent webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.completed event when a document workflow is completed.
  """
  @spec trigger_document_completed(Instance.t()) :: :ok
  def trigger_document_completed(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "completed")
    Webhooks.trigger_webhooks("document.completed", org_id, payload)
    Logger.info("Triggered document.completed webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.cancelled event when a document is cancelled.
  """
  @spec trigger_document_cancelled(Instance.t()) :: :ok
  def trigger_document_cancelled(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "cancelled")
    Webhooks.trigger_webhooks("document.cancelled", org_id, payload)
    Logger.info("Triggered document.cancelled webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.signed event when a document is signed.
  """
  @spec trigger_document_signed(Instance.t()) :: :ok
  def trigger_document_signed(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "signed")
    Webhooks.trigger_webhooks("document.signed", org_id, payload)
    Logger.info("Triggered document.signed webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.rejected event when a document is rejected.
  """
  @spec trigger_document_rejected(Instance.t()) :: :ok
  def trigger_document_rejected(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "rejected")
    Webhooks.trigger_webhooks("document.rejected", org_id, payload)
    Logger.info("Triggered document.rejected webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.state_updated event when a document state is changed.
  """
  @spec trigger_document_state_updated(Instance.t(), map()) :: :ok
  def trigger_document_state_updated(
        %Instance{organisation_id: org_id} = instance,
        previous_state \\ %{}
      ) do
    payload = build_document_state_payload(instance, "state_updated", previous_state)
    Webhooks.trigger_webhooks("document.state_updated", org_id, payload)
    Logger.info("Triggered document.state_updated webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.comment_added event when a comment is added to a document.
  """
  @spec trigger_document_comment_added(Instance.t(), map()) :: :ok
  def trigger_document_comment_added(%Instance{organisation_id: org_id} = instance, comment_data) do
    payload = build_document_comment_payload(instance, "comment_added", comment_data)
    Webhooks.trigger_webhooks("document.comment_added", org_id, payload)
    Logger.info("Triggered document.comment_added webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.deleted event when a document is deleted.
  """
  @spec trigger_document_deleted(Instance.t()) :: :ok
  def trigger_document_deleted(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "deleted")
    Webhooks.trigger_webhooks("document.deleted", org_id, payload)
    Logger.info("Triggered document.deleted webhook document id #{instance.id}")
  end

  @doc """
  Trigger document.reminder_sent event when a reminder is sent for a document.
  """
  @spec trigger_document_reminder_sent(Instance.t(), map()) :: :ok
  def trigger_document_reminder_sent(
        %Instance{organisation_id: org_id} = instance,
        reminder_data \\ %{}
      ) do
    payload = build_document_reminder_payload(instance, "reminder_sent", reminder_data)
    Webhooks.trigger_webhooks("document.reminder_sent", org_id, payload)
    Logger.info("Triggered document.reminder_sent webhook document id #{instance.id}")
  end

  @doc """
  Generic function to trigger any webhook event for a document.
  """
  @spec trigger_event(binary(), Instance.t()) :: :ok
  def trigger_event(event, %Instance{organisation_id: org_id} = instance)
      when event in [
             "document.created",
             "document.sent",
             "document.completed",
             "document.cancelled",
             "document.signed",
             "document.rejected",
             "document.state_updated",
             "document.comment_added",
             "document.deleted",
             "document.reminder_sent"
           ] do
    action = event |> String.split(".") |> List.last()
    payload = build_document_payload(instance, action)
    Webhooks.trigger_webhooks(event, org_id, payload)
    Logger.info("Triggered #{event} webhook document id #{instance.id}")
  end

  def trigger_event(event, _instance) do
    Logger.warning("Unknown or unsupported webhook event: #{event}")
    :ok
  end

  @doc """
  Trigger pipeline.completed event when a pipeline execution completes successfully.
  """
  @spec trigger_pipeline_completed(TriggerHistory.t(), map()) :: :ok
  def trigger_pipeline_completed(
        %TriggerHistory{pipeline: %{organisation_id: org_id}} = trigger_history,
        pipeline_result
      ) do
    payload = build_pipeline_payload(trigger_history, pipeline_result, "completed")
    Webhooks.trigger_webhooks("pipeline.completed", org_id, payload)

    Logger.info(
      "Triggered pipeline.completed webhook for pipeline id #{trigger_history.pipeline_id}"
    )
  end

  def trigger_pipeline_completed(%TriggerHistory{} = trigger_history, _pipeline_result) do
    Logger.warning(
      "Cannot trigger pipeline.completed webhook: pipeline not preloaded for trigger_history #{trigger_history.id}"
    )

    :ok
  end

  @doc """
  Trigger pipeline.failed event when a pipeline execution fails.
  """
  @spec trigger_pipeline_failed(TriggerHistory.t(), map()) :: :ok
  def trigger_pipeline_failed(
        %TriggerHistory{pipeline: %{organisation_id: org_id}} = trigger_history,
        error_data
      ) do
    payload = build_pipeline_payload(trigger_history, error_data, "failed")
    Webhooks.trigger_webhooks("pipeline.failed", org_id, payload)

    Logger.info(
      "Triggered pipeline.failed webhook for pipeline id #{trigger_history.pipeline_id}"
    )
  end

  def trigger_pipeline_failed(%TriggerHistory{} = trigger_history, _error_data) do
    Logger.warning(
      "Cannot trigger pipeline.failed webhook: pipeline not preloaded for trigger_history #{trigger_history.id}"
    )

    :ok
  end

  @doc """
  Trigger pipeline.partially_completed event when a pipeline execution partially completes.
  """
  @spec trigger_pipeline_partially_completed(TriggerHistory.t(), map()) :: :ok
  def trigger_pipeline_partially_completed(
        %TriggerHistory{pipeline: %{organisation_id: org_id}} = trigger_history,
        pipeline_result
      ) do
    payload = build_pipeline_payload(trigger_history, pipeline_result, "partially_completed")
    Webhooks.trigger_webhooks("pipeline.partially_completed", org_id, payload)

    Logger.info(
      "Triggered pipeline.partially_completed webhook for pipeline id #{trigger_history.pipeline_id}"
    )
  end

  def trigger_pipeline_partially_completed(%TriggerHistory{} = trigger_history, _pipeline_result) do
    Logger.warning(
      "Cannot trigger pipeline.partially_completed webhook: pipeline not preloaded for trigger_history #{trigger_history.id}"
    )

    :ok
  end

  # Private helper function to build consistent document payload
  defp build_document_payload(%Instance{} = instance, action) do
    %{
      document: %{
        id: instance.id,
        instance_id: instance.instance_id,
        title: get_in(instance.serialized, ["title"]) || "Untitled Document",
        content_type: get_content_type_info(instance),
        state: get_state_info(instance),
        creator: get_creator_info(instance),
        organisation_id: instance.organisation_id,
        action: action,
        created_at: instance.inserted_at,
        updated_at: instance.updated_at
      }
    }
  end

  defp get_content_type_info(%Instance{content_type: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_content_type_info(%Instance{content_type: nil}), do: nil

  defp get_content_type_info(%Instance{content_type: content_type}) do
    %{
      id: content_type.id,
      name: content_type.name,
      description: content_type.description
    }
  end

  defp get_state_info(%Instance{state: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_state_info(%Instance{state: nil}), do: nil

  defp get_state_info(%Instance{state: state}) do
    %{
      id: state.id,
      state: state.state,
      order: state.order
    }
  end

  defp get_creator_info(%Instance{creator: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_creator_info(%Instance{creator: nil}), do: nil

  defp get_creator_info(%Instance{creator: creator}) do
    %{
      id: creator.id,
      name: creator.name,
      email: creator.email
    }
  end

  # Build payload for document state update events
  defp build_document_state_payload(%Instance{} = instance, action, previous_state) do
    base_payload = build_document_payload(instance, action)

    state_changes = %{
      previous_state: previous_state,
      current_state: get_state_info(instance)
    }

    put_in(base_payload, [:document, :state_changes], state_changes)
  end

  # Build payload for document comment events
  defp build_document_comment_payload(%Instance{} = instance, action, comment_data) do
    base_payload = build_document_payload(instance, action)

    comment_info = %{
      comment_id: Map.get(comment_data, :id),
      comment_text: Map.get(comment_data, :comment),
      commenter: %{
        id: Map.get(comment_data, :user_id),
        name: Map.get(comment_data, :user_name),
        email: Map.get(comment_data, :user_email)
      },
      commented_at: Map.get(comment_data, :inserted_at)
    }

    put_in(base_payload, [:document, :comment], comment_info)
  end

  # Build payload for document reminder events
  defp build_document_reminder_payload(%Instance{} = instance, action, reminder_data) do
    base_payload = build_document_payload(instance, action)

    reminder_info = %{
      reminder_type: Map.get(reminder_data, :type, "general"),
      reminder_message: Map.get(reminder_data, :message),
      recipients: Map.get(reminder_data, :recipients, []),
      sent_at: Map.get(reminder_data, :sent_at, DateTime.utc_now())
    }

    put_in(base_payload, [:document, :reminder], reminder_info)
  end

  # Build payload for pipeline events with JSON support
  defp build_pipeline_payload(%TriggerHistory{} = trigger_history, result_data, status) do
    # Ensure all data is JSON-serializable
    pipeline_info = %{
      pipeline_id: trigger_history.pipeline_id,
      trigger_history_id: trigger_history.id,
      status: status,
      input_data: ensure_json_serializable(trigger_history.data),
      state: TriggerHistory.get_state(trigger_history),
      start_time: format_datetime(trigger_history.start_time),
      end_time: format_datetime(trigger_history.end_time),
      duration_ms: trigger_history.duration,
      created_at: format_datetime(trigger_history.inserted_at),
      updated_at: format_datetime(trigger_history.updated_at)
    }

    # Add pipeline-specific result data
    pipeline_info =
      case status do
        "completed" ->
          instances = Map.get(result_data, :documents, [])

          Map.merge(pipeline_info, %{
            documents_count: Map.get(result_data, :documents_count),
            documents: build_instances_payload(instances),
            success: true
          })

        "partially_completed" ->
          instances = Map.get(result_data, :documents, [])

          Map.merge(pipeline_info, %{
            failed_builds: ensure_json_serializable(Map.get(result_data, :failed_builds, [])),
            documents_count: Map.get(result_data, :documents_count),
            documents: build_instances_payload(instances),
            success: false
          })

        "failed" ->
          Map.merge(pipeline_info, %{
            error: ensure_json_serializable(Map.get(result_data, :error, %{})),
            error_message: Map.get(result_data, :message, "Pipeline execution failed"),
            success: false
          })

        _ ->
          pipeline_info
      end

    %{pipeline: pipeline_info}
  end

  # Helper to ensure data is JSON-serializable (convert atoms, dates, etc.)
  defp ensure_json_serializable(data) when is_map(data) do
    data
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), ensure_json_serializable(v)}
      {k, v} -> {k, ensure_json_serializable(v)}
    end)
    |> Enum.into(%{})
  end

  defp ensure_json_serializable(data) when is_list(data) do
    Enum.map(data, &ensure_json_serializable/1)
  end

  defp ensure_json_serializable(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp ensure_json_serializable(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp ensure_json_serializable(%Date{} = d), do: Date.to_iso8601(d)
  defp ensure_json_serializable(data) when is_atom(data), do: Atom.to_string(data)
  defp ensure_json_serializable(data), do: data

  # Format datetime for JSON
  defp format_datetime(nil), do: nil
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(dt), do: dt

  # Build instances payload for pipeline webhooks
  defp build_instances_payload(instances) when is_list(instances) do
    instances
    |> Enum.map(&build_instance_summary/1)
    |> ensure_json_serializable()
  end

  defp build_instances_payload(_), do: []

  # Build a summary of an instance for webhook payload
  defp build_instance_summary(%Instance{} = instance) do
    %{
      id: instance.id,
      instance_id: instance.instance_id,
      title: get_in(instance.serialized, ["title"]) || "Untitled Document",
      content_type: get_content_type_info(instance),
      state: get_state_info(instance),
      organisation_id: instance.organisation_id,
      created_at: format_datetime(instance.inserted_at),
      updated_at: format_datetime(instance.updated_at)
    }
  end

  defp build_instance_summary(_), do: %{}
end
