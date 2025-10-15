defmodule WraftDoc.Workers.CloudImportWorker do
  @moduledoc """
  Oban worker for handling Google Drive operations in the background.
  Supports downloading and exporting files from Google Drive.
  Can handle single file IDs or lists of file IDs.
  Can store files locally or in MinIO storage.
  """

  use Oban.Worker, queue: :cloud_provider, max_attempts: 3

  require Logger
  alias WraftDoc.Client.Minio
  # alias WraftDoc.CloudImport.Clouds
  alias WraftDoc.CloudImport.Providers.GoogleDrive

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"file_ids" => file_ids} = args
      }) do
    folder_id = Map.get(args, "folder_id")
    org_id = Map.get(args, "org_id")
    store_in_minio = Map.get(args, "store_in_minio", false)
    minio_path = Map.get(args, "minio_path")
    user_id = Map.get(args, "user_id")

    file_ids = normalize_file_ids(file_ids)

    results =
      Enum.map(file_ids, fn id ->
        process_download(id, org_id, user_id, folder_id, store_in_minio, minio_path)
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

  # Normalize file_id input - handles both single strings and lists
  defp normalize_file_ids(file_id) when is_list(file_id), do: file_id
  defp normalize_file_ids(file_id) when is_binary(file_id), do: [file_id]

  # Process individual download
  defp process_download(file_id, org_id, user_id, folder_id, store_in_minio, minio_path) do
    case GoogleDrive.download_file(user_id, file_id, org_id, folder_id) do
      {:ok, %{content: content, metadata: metadata} = result} when store_in_minio ->
        # Store in MinIO if requested
        file_name = metadata["name"]
        full_minio_path = build_minio_path(minio_path, file_name, file_id)

        case upload_to_minio(full_minio_path, content) do
          {:ok, _} ->
            Logger.info(
              "Successfully downloaded file #{file_id} and stored in MinIO at #{full_minio_path}"
            )

            {:ok, %{file_id: file_id, result: Map.put(result, :minio_path, full_minio_path)}}

          {:error, minio_error} = _error ->
            Logger.error("Failed to store file #{file_id} in MinIO: #{inspect(minio_error)}")
            {:error, %{file_id: file_id, error: minio_error}}
        end

      {:ok, result} ->
        # Regular download without MinIO storage
        Logger.info("Successfully downloaded file #{file_id}")
        {:ok, %{file_id: file_id, result: result}}

      {:error, reason} = _error ->
        Logger.error("Failed to download file #{file_id}: #{inspect(reason)}")
        {:error, %{file_id: file_id, error: reason}}
    end
  end

  # Build MinIO path, handling multiple files by appending file_id if needed
  defp build_minio_path(nil, file_name, _file_id), do: file_name

  defp build_minio_path(minio_path, file_name, file_id) when is_list(minio_path) do
    # If multiple files and minio_path is a list, use corresponding path
    case Enum.at(minio_path, 0) do
      nil -> "#{file_id}_#{file_name}"
      path -> path
    end
  end

  defp build_minio_path(minio_path, _file_name, _file_id), do: minio_path

  # Summarize results from multiple file operations
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

  # Helper function to upload content to MinIO
  defp upload_to_minio(path, content) do
    # Create a temporary file
    temp_file = Path.join(System.tmp_dir(), "#{:rand.uniform(1_000_000)}_#{Path.basename(path)}")

    with :ok <- File.write(temp_file, content),
         {:ok, _} = result <- Minio.upload_file(temp_file) do
      # Clean up the temporary file
      File.rm(temp_file)
      result
    else
      error ->
        # Clean up on error too
        File.rm(temp_file)
        error
    end
  end
end
