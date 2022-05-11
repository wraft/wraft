defmodule WraftDocWeb.Plug.ExAuditTrack do
  @moduledoc """
  Plug to track the User ID in custom ex_audit data.
  """
  def init(_) do
    nil
  end

  def call(conn, _) do
    ExAudit.track(user_id: conn.assigns.current_user.id)
    conn
  end
end
