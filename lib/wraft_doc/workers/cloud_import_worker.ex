defmodule WraftDoc.Workers.CloudImportWorker do
  @moduledoc """
  Oban worker for handling Google Drive operations in the background.
  Supports downloading and exporting files from Google Drive.
  Can handle single file IDs or lists of file IDs.
  Can store files locally or in MinIO storage.
  """

  use Oban.Worker, queue: :cloud_provider, max_attempts: 3
  require Logger

  alias WraftDoc.CloudImport.Providers.GoogleDrive
  alias WraftDoc.Storage
  alias WraftDoc.Storage.StorageItems

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "file_ids" => file_ids,
            "folder_id" => folder_id,
            "org_id" => org_id,
            "user_id" => user_id
          } = _args
      }) do
    results =
      file_ids
      |> normalize_file_ids()
      |> Enum.map(fn id ->
        process_download(id, org_id, user_id, folder_id)
      end)

    case summarize_results(results, "download") do
      {:ok, summary} -> {:ok, summary}
      {:error, _} = error -> error
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid job arguments: #{inspect(args)}")
    {:error, "Invalid job arguments"}
  end

  defp normalize_file_ids(file_id) when is_list(file_id), do: file_id
  defp normalize_file_ids(file_id) when is_binary(file_id), do: [file_id]

  defp process_download(external_id, org_id, user_id, folder_id) do
    case GoogleDrive.download_file(user_id, external_id, org_id, folder_id) do
      {:ok, %{content: content, metadata: metadata} = result} ->
        temp_path = Briefly.create!()
        File.write(temp_path, content)

        with {:ok, upload_params} <-
               Storage.prepare_upload_params(
                 %{
                   "file" => %Plug.Upload{
                     filename: metadata["name"],
                     path: temp_path,
                     content_type: metadata["mimeType"]
                   }
                 },
                 %{id: user_id, current_org_id: org_id},
                 org_id
               ),
             {:ok, %{file_id: file_id}} <-
               Storage.execute_upload_transaction(%{
                 upload_params
                 | storage_item: Map.put(upload_params.storage_item, "external_id", external_id)
               }) do
          {:ok, %{file_id: file_id, result: result}}
        end

      {:ok, result} ->
        Logger.info("Successfully downloaded file #{external_id}")
        {:ok, %{file_id: external_id, result: result}}

      {:error, reason} = _error ->
        Logger.error("Failed to download file #{external_id}: #{inspect(reason)}")
        StorageItems.update_upload_status(external_id, "failed")
        {:error, %{file_id: external_id, error: reason}}
    end
  end

  defp summarize_results(results, operation) do
    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    success_data = Enum.map(successes, fn {:ok, data} -> data end)
    failure_data = Enum.map(failures, fn {:error, data} -> data end)

    total_files = length(results)
    successful_files = length(successes)
    failed_files = length(failures)

    Logger.info("#{operation} operation completed: #{successful_files}/#{total_files} successful")

    if failed_files > 0 do
      Logger.error("#{failed_files} files failed during #{operation}")
    end

    cond do
      failed_files == 0 ->
        {:ok,
         %{
           operation: operation,
           total_files: total_files,
           successful_files: successful_files,
           failed_files: failed_files,
           results: success_data
         }}

      successful_files == 0 ->
        {:error,
         %{
           operation: operation,
           total_files: total_files,
           successful_files: successful_files,
           failed_files: failed_files,
           errors: failure_data
         }}

      true ->
        {:ok,
         %{
           operation: operation,
           total_files: total_files,
           successful_files: successful_files,
           failed_files: failed_files,
           results: success_data,
           errors: failure_data
         }}
    end
  end
end
