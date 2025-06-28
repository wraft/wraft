defmodule WraftDocWeb.Api.V1.AccessLogController do
  use WraftDocWeb, :controller

  alias WraftDoc.Storage.AccessLog
  alias WraftDoc.Storage.StorageAcessLogs

  action_fallback(WraftDocWeb.FallbackController)

  def index(conn, _params) do
    storage_access_logs = StorageAcessLogs.list_storage_access_logs()
    render(conn, :index, storage_access_logs: storage_access_logs)
  end

  def create(conn, %{"access_log" => access_log_params}) do
    with {:ok, %AccessLog{} = access_log} <-
           StorageAcessLogs.create_access_log(access_log_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_access_logs/#{access_log}")
      |> render(:show, access_log: access_log)
    end
  end

  def show(conn, %{"id" => id}) do
    access_log = StorageAcessLogs.get_access_log!(id)
    render(conn, :show, access_log: access_log)
  end

  def update(conn, %{"id" => id, "access_log" => access_log_params}) do
    access_log = StorageAcessLogs.get_access_log!(id)

    with {:ok, %AccessLog{} = access_log} <-
           StorageAcessLogs.update_access_log(access_log, access_log_params) do
      render(conn, :show, access_log: access_log)
    end
  end

  def delete(conn, %{"id" => id}) do
    access_log = StorageAcessLogs.get_access_log!(id)

    with {:ok, %AccessLog{}} <- StorageAcessLogs.delete_access_log(access_log) do
      send_resp(conn, :no_content, "")
    end
  end
end
