defmodule WraftDoc.Storage.StorageAcessLogs do
  @moduledoc """
  The sync job model.
  """
  alias WraftDoc.Repo
  alias WraftDoc.Storage.AccessLog

  def list_storage_access_logs do
    Repo.all(AccessLog)
  end

  def get_access_log!(id), do: Repo.get!(AccessLog, id)

  def create_access_log(attrs \\ %{}) do
    %AccessLog{}
    |> AccessLog.changeset(attrs)
    |> Repo.insert()
  end

  def update_access_log(%AccessLog{} = access_log, attrs) do
    access_log
    |> AccessLog.changeset(attrs)
    |> Repo.update()
  end

  def delete_access_log(%AccessLog{} = access_log) do
    Repo.delete(access_log)
  end

  def change_access_log(%AccessLog{} = access_log, attrs \\ %{}) do
    AccessLog.changeset(access_log, attrs)
  end

  def create_upload_access_log(storage_item, storage_asset, enriched_params) do
    access_log_params = %{
      action: "upload",
      # Should be extracted from request context
      ip_address: "127.0.0.1",
      # Should be extracted from request context
      user_agent: "Web Browser",
      session_id: Ecto.UUID.generate(),
      metadata: %{
        filename: storage_item.name,
        file_size: storage_item.size,
        mime_type: storage_item.mime_type
      },
      success: true,
      storage_item_id: storage_item.id,
      storage_asset_id: storage_asset.id,
      user_id: enriched_params.current_user && enriched_params.current_user.id,
      repository_id: storage_item.repository_id
    }

    create_access_log(access_log_params)
  end
end
