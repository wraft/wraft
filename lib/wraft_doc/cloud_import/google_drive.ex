defmodule WraftDoc.CloudImport.GoogleDrive do
  @moduledoc """
  Cloud service client for Google Drive APIs.
  """
  use Tesla
  require Logger
  alias WraftDoc.Storage.StorageItems
  alias WraftDoc.Workers.CloudImportWorker, as: Worker

  @google_drive_base "https://www.googleapis.com/drive/v3"
  plug Tesla.Middleware.Headers, [
    {"user-agent", "wraftdoc"}
  ]

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.FollowRedirects
  plug Tesla.Middleware.Logger

  adapter(Tesla.Adapter.Hackney,
    timeout: 15_000,
    recv_timeout: 15_000
  )

  def list_all_files(access_token, opts) do
    page_size = Map.get(opts, "page_size", 1000)
    query = Map.get(opts, "query", "")
    page_token = Map.get(opts, "page_token")

    fields =
      "nextPageToken,files(id,name,mimeType,description,size,createdTime,modifiedTime,owners,parents,fileExtension)"

    query_params = %{
      pageSize: page_size,
      fields: fields,
      q: query
    }

    query_params =
      if page_token, do: Map.put(query_params, :pageToken, page_token), else: query_params

    handle_response(
      get(
        "#{@google_drive_base}/files",
        query: query_params,
        headers: auth_headers(access_token)
      )
    )
  end

  def list_all_files_recursive(access_token, params, acc \\ []) do
    case list_all_files(access_token, params) do
      {:ok, %{"files" => files, "nextPageToken" => next_token}} ->
        new_params = Map.put(params, "page_token", next_token)
        list_all_files_recursive(access_token, new_params, acc ++ files)

      {:ok, %{"files" => files}} ->
        {:ok, acc ++ files}

      error ->
        error
    end
  end

  def get_file_metadata(access_token, file_id) do
    fields =
      "id,name,mimeType,size,description,createdTime,modifiedTime,owners,parents,fileExtension"

    handle_response(
      get("#{@google_drive_base}/files/#{file_id}",
        query: [fields: fields],
        headers: auth_headers(access_token)
      )
    )
  end

  def list_all_pdfs(access_token, params \\ [])

  def list_all_pdfs(access_token, params) do
    opts = Map.to_list(params)
    page_size = Keyword.get(opts, :page_size, 1000)

    handle_response(
      get("#{@google_drive_base}/files",
        query: [
          q: "mimeType = 'application/pdf'",
          pageSize: page_size,
          fields: "nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink)"
        ],
        headers: auth_headers(access_token)
      )
    )
  end

  def sync_files_to_db(access_token, params, org_id) do
    with {:ok, %{"files" => files}} <- list_all_files(access_token, params) do
      results =
        files
        |> Enum.map(&Task.async(fn -> save_files_to_db(&1, org_id) end))
        |> Enum.map(&Task.await(&1, 15_000))

      stats = calculate_sync_stats(results, files)

      {:ok, stats}
    end
  end

  def search_files(access_token, opts) do
    # Convert opts to map if it's a keyword list
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    query = Map.get(opts, "query", "") || Map.get(opts, :query, "")
    content_type = Map.get(opts, "content_type") || Map.get(opts, :content_type)
    limit = Map.get(opts, "limit", 100) || Map.get(opts, :limit, 100)

    search_google_drive(access_token, query, content_type, limit)
  end

  def download_file(access_token, file_id, output_path \\ nil) do
    with {:ok, metadata} <- get_file_metadata(access_token, file_id),
         :ok <- save_files_to_db(metadata),
         {:ok, %{status: 200, body: body}} <-
           get("#{@google_drive_base}/files/#{file_id}",
             query: [alt: "media"],
             headers: auth_headers(access_token)
           ) do
      write_file_result(body, output_path, metadata)
    else
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      error -> error
    end
  end

  def schedule_download_to_minio(access_token, file_id, org_id, metadata \\ %{}) do
    action = String.replace("download_google_drive_to_minio", "_drive", "")

    params = %{
      action: action,
      file_id: file_id,
      access_token: access_token,
      org_id: org_id,
      user_id: metadata["user_id"],
      notification_enabled: Map.get(metadata, "notification_enabled", true)
    }

    params
    |> Worker.new()
    |> Oban.insert()
  end

  def list_all_folders(access_token, params) do
    opts = Map.to_list(params)
    page_size = Keyword.get(opts, :page_size, 100)
    parent_id = Keyword.get(opts, :parent_id, "root")

    query =
      if parent_id == "root" do
        "mimeType = 'application/vnd.google-apps.folder'"
      else
        "mimeType = 'application/vnd.google-apps.folder' and '#{parent_id}' in parents"
      end

    fields =
      "nextPageToken, files(id, name, mimeType, createdTime, modifiedTime, owners, parents)"

    handle_response(
      get(
        "#{@google_drive_base}/files",
        query: [
          pageSize: page_size,
          fields: fields,
          q: query
        ],
        headers: auth_headers(access_token)
      )
    )
  end

  def search_folders(access_token, opts) do
    opts = Map.to_list(opts)
    query = Keyword.get(opts, :query, "")
    page_size = Keyword.get(opts, :page_size, 100)

    search_query =
      if query == "" do
        "mimeType = 'application/vnd.google-apps.folder'"
      else
        "mimeType = 'application/vnd.google-apps.folder' and name contains '#{query}'"
      end

    fields =
      "nextPageToken, files(id, name, mimeType, createdTime, modifiedTime, owners, parents)"

    handle_response(
      get(
        "#{@google_drive_base}/files",
        query: [
          pageSize: page_size,
          fields: fields,
          q: search_query
        ],
        headers: auth_headers(access_token)
      )
    )
  end

  def list_files_in_folder(access_token, folder_id, params) do
    opts = Map.to_list(params)
    page_size = Keyword.get(opts, :page_size, 100)
    file_type = Keyword.get(opts, :file_type, "all")

    base_query = "'#{folder_id}' in parents and trashed = false"

    query =
      case file_type do
        "pdf" ->
          "#{base_query} and mimeType = 'application/pdf'"

        "image" ->
          "#{base_query} and (mimeType contains 'image/')"

        "document" ->
          "#{base_query} and (mimeType contains 'document' or mimeType contains 'text')"

        _ ->
          base_query
      end

    fields =
      "nextPageToken, files(id, name, mimeType, description, size, createdTime, modifiedTime, owners, parents, fileExtension, webViewLink)"

    handle_response(
      get(
        "#{@google_drive_base}/files",
        query: [
          pageSize: page_size,
          fields: fields,
          q: query
        ],
        headers: auth_headers(access_token)
      )
    )
  end

  def get_folder_metadata(access_token, folder_id) do
    fields = "id,name,mimeType,createdTime,modifiedTime,owners,parents,description"

    handle_response(
      get("#{@google_drive_base}/files/#{folder_id}",
        query: [fields: fields],
        headers: auth_headers(access_token)
      )
    )
  end

  defp auth_headers(access_token) do
    [{"Authorization", "Bearer #{access_token}"}]
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}) do
    {:error, %{status: 500, body: reason}}
  end

  defp write_file_result(content, nil, metadata) do
    {:ok, %{content: content, metadata: metadata}}
  end

  defp write_file_result(content, output_path, metadata) do
    case File.write(output_path, content) do
      :ok -> {:ok, %{path: output_path, metadata: metadata}}
      {:error, reason} -> {:error, "Failed to write file: #{inspect(reason)}"}
    end
  end

  defp calculate_sync_stats(results, files) do
    success_count = Enum.count(results, &(&1 == :ok))

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

  defp save_files_to_db(file, _org \\ nil) do
    attrs = %{
      sync_source: "google_drive",
      external_id: file["id"],
      name: file["name"],
      # organisation_id: org,
      repository_id: file["repository_id"] || nil,
      path: file["pathDisplay"] || "root",
      materialized_path: file["pathDisplay"] || "no_path",
      mime_type: file["mimeType"],
      item_type: "default",
      metadata: %{description: file["description"] || ""},
      size: parse_size(file["size"]),
      modified_time: file["modifiedTime"],
      external_metadata: %{
        owner: file["owners"],
        created_time: file["createdTime"],
        parents: file["parents"]
      },
      file_extension: file["fileExtension"]
    }

    # |> IO.inspect(label: "Google Drive File Attributes")
    case StorageItems.create_storage_item(attrs) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp search_google_drive(access_token, query, content_type, limit) do
    safe_query = String.replace(query, "'", "''")

    conditions =
      [
        "trashed = false",
        if(safe_query != "", do: "name contains '#{safe_query}'"),
        if(content_type, do: "mimeType = '#{content_type}'")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" and ")

    handle_response(
      get("#{@google_drive_base}/files",
        query: [
          q: conditions,
          pageSize: limit,
          fields: "files(id,name,mimeType,modifiedTime,size,webViewLink)"
        ],
        headers: auth_headers(access_token)
      )
    )
  end
end
