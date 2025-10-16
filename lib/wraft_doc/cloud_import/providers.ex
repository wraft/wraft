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
  @callback download_file(Ecto.UUID.t(), file_id, Ecto.UUID.t(), String.t()) :: result
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
      alias WraftDoc.Storage
      alias WraftDoc.Storage.StorageItem
      alias WraftDoc.Storage.StorageItems
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

      def sync_files_to_db(access_token, params, org_id \\ nil) do
        with repository <-
               Storage.get_latest_repository(org_id),
             {:ok, parent} <- setup_sync_folder(repository),
             {:ok, %{"files" => files}} <- list_all_files(access_token, params) do
          files
          |> Enum.map(
            &Task.async(fn ->
              save_files_to_db(&1, repository.id, parent.id, org_id, "google_drive_files")
            end)
          )
          |> Enum.map(&Task.await(&1, 15_000))
          |> calculate_sync_stats(files)
          |> then(&{:ok, &1})
        end
      end

      def schedule_download_to_minio(
            %{id: user_id, current_org_id: org_id},
            file_ids,
            %StorageItem{id: folder_id, materialized_path: materialized_path}
          ) do
        provider_name = __MODULE__ |> Module.split() |> List.last() |> String.downcase()
        action = "download_#{provider_name}_to_minio"

        %{
          "action" => action,
          "file_ids" => file_ids,
          "org_id" => org_id,
          "folder_id" => folder_id,
          "user_id" => user_id,
          "store_in_minio" => true,
          "minio_path" => materialized_path,
          "notification_enabled" => true
        }
        |> CloudImportWorker.new()
        |> Oban.insert()
      end

      defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299,
        do: {:ok, body}

      defp handle_response(
             {:ok,
              %{
                status: 401,
                body:
                  %{
                    "error" => %{
                      "message" => error_msg
                    }
                  } = _body
              }}
           ),
           do: {:error, {403, %{errors: error_msg}}}

      defp handle_response(
             {:ok,
              %{
                status: status,
                body:
                  %{
                    "error" => %{
                      "message" => error_msg
                    }
                  } = _body
              }}
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

      defp parse_size(nil), do: 0
      defp parse_size(size) when is_binary(size), do: String.to_integer(size)
      defp parse_size(size) when is_integer(size), do: size
      defp parse_size(_), do: 0

      defp write_file_result(content, nil, metadata),
        do: {:ok, %{content: content, metadata: metadata}}

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
             repository_id,
             parant_id,
             org_id,
             base_path,
             optional_param \\ %{}
           ) do
        file
        |> build_storage_attrs(repository_id, parant_id, org_id, base_path, optional_param)
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
