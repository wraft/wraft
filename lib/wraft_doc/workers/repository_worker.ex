defmodule WraftDoc.Workers.RepositoryWorker do
  @moduledoc """
  Oban worker for handling Google Drive operations in the background.
  Supports downloading and exporting files from Google Drive.
  Can handle single file IDs or lists of file IDs.
  Can store files locally or in MinIO Storages.
  """

  use Oban.Worker, queue: :repository, max_attempts: 3
  require Logger

  alias WraftDoc.Client.Minio
  alias WraftDoc.Notifications.Delivery
  alias WraftDoc.Storages

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "current_user" => %{"id" => user_id, "current_org_id" => org_id} = current_user,
            "file_name" => file_name
          } = _args
      }) do
    current_user =
      current_user
      |> atomize_keys()
      |> then(&struct(WraftDoc.Account.User, &1))

    file_name = "#{file_name}_#{System.system_time(:second)}.zip"
    minio_key = "organisations/#{org_id}/exports/#{file_name}"

    zip_path = Storages.export_repository(current_user, file_name)

    Minio.upload_file(zip_path)

    download_url = Minio.generate_url(minio_key, expires_in: 600)

    Delivery.dispatch(current_user, "repository.exported", %{
      button_url: download_url,
      message: "Your repository has been successfully exported.",
      button_text: "Download Export",
      additional_info: "The link is valid for 10 minutes.",
      signature: "Wraft Team",
      channel: :user_notification,
      channel_id: user_id,
      metadata: %{}
    })

    Storages.repository_zip_deletion_worker(minio_key)

    {:ok, :export_completed}
  end

  def perform(%Oban.Job{args: %{"key" => key}}) do
    Minio.delete_file(key)
    {:ok, :deleted}
  end

  def perform(%Oban.Job{args: %{"action" => "update_repo_size"}}) do
    Enum.each(Storages.list_repositories(), fn repository ->
      Storages.update_repository_storage_size(
        repository.id,
        repository.organisation_id
      )
    end)

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid job arguments: #{inspect(args)}")
    {:error, "Invalid job arguments"}
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_map(v) -> {String.to_atom(k), atomize_keys(v)}
      {k, v} -> {String.to_atom(k), v}
    end)
  end
end
