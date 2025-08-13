defmodule WraftDoc.Documents.ActionLog do
  @moduledoc """
    This module defines the Document ActionLog schema.
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

  def changeset(action_log, attrs) do
    action_log
    |> cast(attrs, [
      :actor,
      :action,
      :user_id,
      :document_id,
      :remote_ip,
      :actor_agent,
      :request_path,
      :request_method,
      :params
    ])
    |> validate_required([:action, :user_id])
  end
end
