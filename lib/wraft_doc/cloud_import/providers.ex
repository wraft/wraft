defmodule WraftDoc.CloudImport.Providers do
  @moduledoc """
  Behaviour for cloud storage providers.
  Defines the contract that all cloud providers must implement.
  """

  @type access_token :: String.t()
  @type file_id :: String.t()
  @type folder_id :: String.t()
  @type params :: map() | keyword()
  @type result :: {:ok, map()} | {:error, map()}

  @callback list_all_files(access_token, params) :: result
  @callback list_all_files_recursive(access_token, params, list()) :: result
  @callback get_file_metadata(access_token, file_id) :: result
  @callback list_all_pdfs(access_token, params) :: result
  @callback search_files(access_token, params) :: result
  @callback list_all_folders(access_token, params) :: result
  @callback search_folders(access_token, params) :: result
  @callback list_files_in_folder(access_token, folder_id, params) :: result
  @callback get_folder_metadata(access_token, folder_id) :: result

  defmacro __using__(opts) do
    base_url = Keyword.fetch!(opts, :base_url)

    quote do
      @behaviour unquote(__MODULE__)
      use Tesla
      require Logger

      alias WraftDoc.Account.User
      alias WraftDoc.Integrations
      alias WraftDoc.Storages
      alias WraftDoc.Storages.StorageItem
      alias WraftDoc.Storages.StorageItems
      alias WraftDoc.Workers.CloudImportWorker

      @base_url unquote(base_url)

      plug Tesla.Middleware.Headers, [{"user-agent", "wraftdoc"}]
      plug Tesla.Middleware.JSON
      plug Tesla.Middleware.FollowRedirects
      plug Tesla.Middleware.Logger

      adapter(Tesla.Adapter.Hackney,
        timeout: 15_000,
        recv_timeout: 15_000
      )

      def sync_files_to_db(access_token, params, current_user) do
        with %{id: repository_id} = repository <-
               Storages.get_latest_repository(current_user.current_org_id),
             {:ok, parent_folder} <- setup_sync_folder(repository),
             {:ok, %{"files" => files}} <- list_all_files(access_token, params) do
          files
          |> Task.async_stream(
            fn file ->
              save_files_to_db(
                file,
                current_user,
                repository_id,
                parent_folder,
                "google_drive_files"
              )
            end,
            max_concurrency: 5,
            timeout: 30_000,
            on_timeout: :kill_task
          )
          |> Enum.map(fn
            {:ok, result} -> result
            {:exit, reason} -> {:error, reason}
          end)
          |> calculate_sync_stats(files)
          |> then(&{:ok, &1})
        end
      end

      def schedule_download_to_minio(
            %{id: user_id, current_org_id: org_id},
            storage_items,
            %StorageItem{id: folder_id, materialized_path: materialized_path}
          ) do
        provider_name = __MODULE__ |> Module.split() |> List.last() |> String.downcase()
        action = "download_#{provider_name}_to_minio"

        %{
          "storage_item_ids" => Enum.map(storage_items, & &1.id),
          "action" => action
        }
        |> CloudImportWorker.new()
        |> Oban.insert()
      end

      defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299,
        do: {:ok, body}

      defp handle_response(
             {:ok, %{status: 401, body: %{"error" => %{"message" => error_msg}} = _body}}
           ),
           do: {:error, {403, %{errors: error_msg}}}

      defp handle_response(
             {:ok, %{status: status, body: %{"error" => %{"message" => error_msg}} = _body}}
           ),
           do: {:error, {status, %{errors: error_msg}}}

      defp handle_response({:error, reason}), do: {:error, {500, %{error: reason}}}

      defp calculate_sync_stats(results, files) do
        success_count = Enum.count(results, &match?({:ok, _}, &1))

        %{
          total: length(files),
          success: success_count,
          errors: length(files) - success_count,
          results: results
        }
      end

      defp parse_size(size) when is_binary(size), do: String.to_integer(size)
      defp parse_size(size) when is_integer(size), do: size
      defp parse_size(_), do: 0

      defp write_file_result(content, nil, storage_item),
        do: {:ok, %{content: content, storage_item: storage_item}}

      defp write_file_result(content, output_path, metadata) do
        output_path
        |> File.write(content)
        |> case do
          :ok -> {:ok, %{path: output_path, metadata: metadata}}
          {:error, reason} -> {:error, "Failed to write file: #{inspect(reason)}"}
        end
      end

      defp save_files_to_db(
             file,
             current_user,
             repository_id,
             folder_item,
             base_path,
             optional_param \\ %{}
           ) do
        file
        |> build_storage_attrs(
          current_user,
          repository_id,
          folder_item,
          base_path,
          optional_param
        )
        |> StorageItems.create_storage_item()
      end

      defp auth_headers(token), do: [{"Authorization", "Bearer #{token}"}]

      defp setup_sync_folder(_repository) do
        raise "setup_sync_folder/1 must be implemented by the provider module"
      end

      defoverridable setup_sync_folder: 1

      defp build_storage_attrs(file, org_id) do
        raise "build_storage_attrs/2 must be implemented by the provider module"
      end

      defoverridable build_storage_attrs: 2
    end
  end
end
