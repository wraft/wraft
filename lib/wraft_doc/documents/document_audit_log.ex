defmodule WraftDoc.Documents.DocumentAuditLog do
  @moduledoc """
  Represents an audit log entry for a document.
  """
  use WraftDoc.Schema

  schema "document_audit_logs" do
    field(:actor, :map, default: %{})
    field(:action, :string)
    field(:message, :string)

    belongs_to(:document, WraftDoc.Documents.Instance)
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :actor,
      :action,
      :message,
      :document_id,
      :user_id
    ])
    |> validate_required([:actor, :action, :document_id])
  end
end
