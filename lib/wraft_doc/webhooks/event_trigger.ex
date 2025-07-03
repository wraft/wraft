defmodule WraftDoc.Webhooks.EventTrigger do
  @moduledoc """
  Module for triggering webhook events based on document state changes.
  """
  require Logger

  alias WraftDoc.Documents.Instance
  alias WraftDoc.Webhooks

  @doc """
  Trigger document.created event when a new document instance is created.
  """
  @spec trigger_document_created(Instance.t()) :: :ok
  def trigger_document_created(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "created")
    Webhooks.trigger_webhooks("document.created", org_id, payload)
    Logger.info("Triggered document.created webhook", instance_id: instance.id)
  end

  @doc """
  Trigger document.sent event when a document is sent for approval.
  """
  @spec trigger_document_sent(Instance.t()) :: :ok
  def trigger_document_sent(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "sent")
    Webhooks.trigger_webhooks("document.sent", org_id, payload)
    Logger.info("Triggered document.sent webhook", instance_id: instance.id)
  end

  @doc """
  Trigger document.completed event when a document workflow is completed.
  """
  @spec trigger_document_completed(Instance.t()) :: :ok
  def trigger_document_completed(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "completed")
    Webhooks.trigger_webhooks("document.completed", org_id, payload)
    Logger.info("Triggered document.completed webhook", instance_id: instance.id)
  end

  @doc """
  Trigger document.cancelled event when a document is cancelled.
  """
  @spec trigger_document_cancelled(Instance.t()) :: :ok
  def trigger_document_cancelled(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "cancelled")
    Webhooks.trigger_webhooks("document.cancelled", org_id, payload)
    Logger.info("Triggered document.cancelled webhook", instance_id: instance.id)
  end

  @doc """
  Trigger document.signed event when a document is signed.
  """
  @spec trigger_document_signed(Instance.t()) :: :ok
  def trigger_document_signed(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "signed")
    Webhooks.trigger_webhooks("document.signed", org_id, payload)
    Logger.info("Triggered document.signed webhook", instance_id: instance.id)
  end

  @doc """
  Trigger document.rejected event when a document is rejected.
  """
  @spec trigger_document_rejected(Instance.t()) :: :ok
  def trigger_document_rejected(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "rejected")
    Webhooks.trigger_webhooks("document.rejected", org_id, payload)
    Logger.info("Triggered document.rejected webhook", instance_id: instance.id)
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
    Logger.info("Triggered document.state_updated webhook", instance_id: instance.id)
  end

  @doc """
  Trigger document.comment_added event when a comment is added to a document.
  """
  @spec trigger_document_comment_added(Instance.t(), map()) :: :ok
  def trigger_document_comment_added(%Instance{organisation_id: org_id} = instance, comment_data) do
    payload = build_document_comment_payload(instance, "comment_added", comment_data)
    Webhooks.trigger_webhooks("document.comment_added", org_id, payload)
    Logger.info("Triggered document.comment_added webhook", instance_id: instance.id)
  end

  @doc """
  Trigger document.deleted event when a document is deleted.
  """
  @spec trigger_document_deleted(Instance.t()) :: :ok
  def trigger_document_deleted(%Instance{organisation_id: org_id} = instance) do
    payload = build_document_payload(instance, "deleted")
    Webhooks.trigger_webhooks("document.deleted", org_id, payload)
    Logger.info("Triggered document.deleted webhook", instance_id: instance.id)
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
    Logger.info("Triggered document.reminder_sent webhook", instance_id: instance.id)
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
    Logger.info("Triggered #{event} webhook", instance_id: instance.id)
  end

  def trigger_event(event, _instance) do
    Logger.warning("Unknown or unsupported webhook event: #{event}")
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
end
