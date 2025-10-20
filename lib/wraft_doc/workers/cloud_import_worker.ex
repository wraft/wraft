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
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItems

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "storage_item_ids" => storage_item_ids
          } = _args
      }) do
    results =
      storage_item_ids
      |> Enum.map(&StorageItems.get_storage_item!/1)
      |> Enum.map(fn storage_item ->
        process_download(storage_item)
      end)

    {:ok, results}
    # case summarize_results(results, "download") do
    #   {:ok, summary} -> {:ok, summary}
    #   {:error, _} = error -> error
    # end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid job arguments: #{inspect(args)}")
    {:error, "Invalid job arguments"}
  end

  defp process_download(
         %{
           id: storage_item_id,
           external_id: external_id,
           organisation_id: organisation_id,
           creator_id: user_id
         } =
           storage_item
       ) do
    case GoogleDrive.download_file(storage_item) do
      {:ok, %{content: content, storage_item: storage_item}} ->
        temp_path = Briefly.create!()
        File.write(temp_path, content)

        upload = %Plug.Upload{
          filename: storage_item.name,
          path: temp_path,
          content_type: storage_item.mime_type
        }

        with {:ok, file_metadata} <- Storage.extract_file_metadata(upload),
             {:ok, storage_asset_params} <-
               StorageAssets.build_storage_asset_params(
                 file_metadata,
                 upload,
                 %{id: user_id, current_org_id: organisation_id}
               ),
             {:ok, _} <-
               StorageAssets.create_storage_asset(
                 Map.put(storage_asset_params, :storage_item_id, storage_item_id)
               ) do
          StorageItems.update_upload_status(storage_item, "completed")
        end

      {:error, reason} = _error ->
        Logger.error("Failed to download file #{external_id}: #{inspect(reason)}")

        StorageItems.update_upload_status(storage_item, "failed")

        {:error, %{file_id: external_id, error: reason}}
    end
  end

  # defp summarize_results(results, operation) do
  #   {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

  #   success_data = Enum.map(successes, fn {:ok, data} -> data end)
  #   failure_data = Enum.map(failures, fn {:error, data} -> data end)

  #   total_files = length(results)
  #   successful_files = length(successes)
  #   failed_files = length(failures)

  #   Logger.info("#{operation} operation completed: #{successful_files}/#{total_files} successful")

  #   if failed_files > 0 do
  #     Logger.error("#{failed_files} files failed during #{operation}")
  #   end

  #   cond do
  #     failed_files == 0 ->
  #       {:ok,
  #        %{
  #          operation: operation,
  #          total_files: total_files,
  #          successful_files: successful_files,
  #          failed_files: failed_files,
  #          results: success_data
  #        }}

  #     successful_files == 0 ->
  #       {:error,
  #        %{
  #          operation: operation,
  #          total_files: total_files,
  #          successful_files: successful_files,
  #          failed_files: failed_files,
  #          errors: failure_data
  #        }}

  #     true ->
  #       {:ok,
  #        %{
  #          operation: operation,
  #          total_files: total_files,
  #          successful_files: successful_files,
  #          failed_files: failed_files,
  #          results: success_data,
  #          errors: failure_data
  #        }}
  #   end
  # end
end
