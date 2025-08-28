defmodule WraftDoc.Documents.DocumentAuditLog do
  @moduledoc """
  Represents an audit log entry for a document.
  """
  use WraftDoc.Schema

  schema "document_audit_logs" do
    field(:actor, :map, default: %{})
    field(:action, :string)
    field(:remote_ip, :string)
    field(:actor_agent, :string)
    field(:request_path, :string)
    field(:request_method, :string)
    field(:params, :map, default: %{})

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
      :remote_ip,
      :actor_agent,
      :request_path,
      :request_method,
      :params,
      :document_id,
      :user_id
    ])
    |> validate_required([:actor, :action, :params, :document_id])
  end
end
