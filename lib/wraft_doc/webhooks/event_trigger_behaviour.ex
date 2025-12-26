defmodule WraftDoc.Webhooks.EventTriggerBehaviour do
  @moduledoc """
  Behaviour for event triggers.
  """

  @callback trigger_document_created(WraftDoc.Documents.Instance.t()) :: :ok
  @callback trigger_document_sent(WraftDoc.Documents.Instance.t()) :: :ok
  @callback trigger_document_state_updated(WraftDoc.Documents.Instance.t(), map()) :: :ok
  @callback trigger_document_approved(WraftDoc.Documents.Instance.t()) :: :ok
  @callback trigger_document_rejected(WraftDoc.Documents.Instance.t()) :: :ok
  @callback trigger_document_deleted(WraftDoc.Documents.Instance.t()) :: :ok
end
