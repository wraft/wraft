defmodule WraftDocWeb.AccessLogJSON do
  @moduledoc """
  Renders access logs for storage operations.
  """
  alias WraftDoc.Storage.AccessLog

  @doc """
  Renders a list of storage_access_logs.
  """
  def index(%{storage_access_logs: storage_access_logs}) do
    %{data: for(access_log <- storage_access_logs, do: data(access_log))}
  end

  @doc """
  Renders a single access_log.
  """
  def show(%{access_log: access_log}) do
    %{data: data(access_log)}
  end

  defp data(%AccessLog{} = access_log) do
    %{
      id: access_log.id,
      action: access_log.action,
      ip_address: access_log.ip_address,
      user_agent: access_log.user_agent,
      session_id: access_log.session_id,
      metadata: access_log.metadata,
      success: access_log.success
    }
  end
end
