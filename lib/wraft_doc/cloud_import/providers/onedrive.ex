defmodule WraftDoc.CloudImport.Providers.Onedrive do
  @moduledoc """
  OneDrive provider implementation for cloud storage integration.
  Implements the CloudProvider behaviour using the Providers module.
  """

  use WraftDoc.CloudImport.Providers, base_url: "https://graph.microsoft.com/v1.0"

  @impl true
  def list_all_files(access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "/drive/root/children")
    query = Keyword.get(opts, :query, "")

    query_params = if query != "", do: [filter: query], else: []

    "#{@base_url}/me#{path}"
    |> get(
      query: query_params,
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  @impl true
  def list_all_files_recursive(access_token, params, acc \\ []) do
    access_token
    |> list_all_files(params)
    |> case do
      {:ok, %{"files" => files, "nextPageToken" => next_token}} ->
        new_params = Map.put(params, "page_token", next_token)
        list_all_files_recursive(access_token, new_params, acc ++ files)

      {:ok, %{"files" => files}} ->
        {:ok, acc ++ files}

      error ->
        error
    end
  end

  @impl true
  def get_file_metadata(access_token, item_id) do
    "#{@base_url}/me/drive/items/#{item_id}"
    |> get(headers: auth_headers(access_token))
    |> handle_response()
  end

  @impl true
  def list_all_pdfs(access_token, params) do
    opts = Map.to_list(params)
    top = Keyword.get(opts, :top, 1000)

    "#{@base_url}/me/drive/root/children"
    |> get(
      query: [
        "$top": top,
        "$select": "id,name,size,lastModifiedDateTime,webUrl,file",
        "$filter": "file ne null"
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
    |> case do
      {:ok, %{"value" => entries}} ->
        pdfs =
          Enum.filter(entries, fn file ->
            name = String.downcase(file["name"] || "")
            String.ends_with?(name, ".pdf") && Map.has_key?(file, "file")
          end)

        {:ok, %{"files" => pdfs}}

      error ->
        error
    end
  end

  @impl true
  def search_files(access_token, opts) do
    # Convert opts to map if it's a keyword list
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    query = Map.get(opts, "query", "") || Map.get(opts, :query, "")
    content_type = Map.get(opts, "content_type") || Map.get(opts, :content_type)
    limit = Map.get(opts, "limit", 100) || Map.get(opts, :limit, 100)

    search_onedrive(access_token, query, content_type, limit)
  end

  def download_file(access_token, file_id, _org, output_path) do
    "#{@base_url}/me/drive/items/#{file_id}/content"
    |> get(headers: auth_headers(access_token))
    |> case do
      {:ok, %{status: status, body: content}} when status in 200..299 ->
        metadata = %{
          file_id: file_id,
          downloaded_at: DateTime.utc_now(),
          size: byte_size(content)
        }

        write_file_result(content, output_path, metadata)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, %{status: 500, body: reason}}
    end
  end

  @impl true
  def list_all_folders(access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "/drive/root/children")

    "#{@base_url}/me#{path}"
    |> get(
      query: [
        "$select": "id,name,createdDateTime,lastModifiedDateTime,folder",
        "$filter": "folder ne null"
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
    |> case do
      {:ok, %{"value" => entries}} ->
        entries
        |> Enum.filter(&Map.has_key?(&1, "folder"))
        |> then(&{:ok, %{"folders" => &1}})

      error ->
        error
    end
  end

  @impl true
  def search_folders(access_token, opts) do
    query = Keyword.get(opts, :query, "")
    top = Keyword.get(opts, :top, 100)

    search_query =
      if query == "" do
        ""
      else
        "search(q='#{query}')"
      end

    endpoint =
      if query == "" do
        "#{@base_url}/me/drive/root/children"
      else
        "#{@base_url}/me/drive/#{search_query}"
      end

    endpoint
    |> get(
      query: [
        "$top": top,
        "$select": "id,name,createdDateTime,lastModifiedDateTime,folder",
        "$filter": "folder ne null"
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
    |> case do
      {:ok, %{"value" => entries}} ->
        folders = Enum.filter(entries, &Map.has_key?(&1, "folder"))
        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  @impl true
  def list_files_in_folder(access_token, folder_id, params) do
    opts = Map.to_list(params)
    top = Keyword.get(opts, :top, 1000)
    file_type = Keyword.get(opts, :file_type, "all")

    filter_query =
      case file_type do
        "pdf" ->
          "file ne null and endswith(name,'.pdf')"

        "image" ->
          "file ne null and (endswith(name,'.jpg') or endswith(name,'.jpeg') or endswith(name,'.png') or endswith(name,'.gif') or endswith(name,'.bmp'))"

        "document" ->
          "file ne null and (endswith(name,'.doc') or endswith(name,'.docx') or endswith(name,'.txt'))"

        _ ->
          "file ne null"
      end

    "#{@base_url}/me/drive/items/#{folder_id}/children"
    |> get(
      query: [
        "$top": top,
        "$select": "id,name,size,lastModifiedDateTime,webUrl,file,createdDateTime",
        "$filter": filter_query
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
    |> case do
      {:ok, %{"value" => entries}} ->
        files = Enum.filter(entries, &Map.has_key?(&1, "file"))
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  @impl true
  def get_folder_metadata(access_token, folder_id) do
    "#{@base_url}/me/drive/items/#{folder_id}"
    |> get(
      query: ["$select": "id,name,createdDateTime,lastModifiedDateTime,folder,parentReference"],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  defp build_storage_attrs(
         file,
         %{id: user_id, current_org_id: organisation_id} = _current_user,
         repository_id,
         parent_id,
         _base_path,
         _optional
       ) do
    %{
      sync_source: "onedrive",
      external_id: file["id"],
      name: file["name"],
      parent_id: parent_id,
      repository_id: repository_id,
      path: file["pathDisplay"] || "",
      materalized_path: file["pathDisplay"] || "",
      mime_type: file["mimeType"],
      metadata: %{description: file["description"] || ""},
      size: parse_size(file["size"]),
      modified_time: file["modifiedTime"],
      external_metadata: %{
        owner: file["owners"],
        created_time: file["createdTime"],
        parents: file["parents"]
      },
      file_extension: file["fileExtension"],
      organisation_id: organisation_id,
      creator_id: user_id
    }
  end

  defp search_onedrive(access_token, query, content_type, limit) do
    query_params = [
      {"$top", to_string(limit)},
      {"$select", "id,name,size,lastModifiedDateTime,file"},
      {"q", query}
    ]

    query_params =
      if content_type do
        [{"$filter", "file/mimeType eq '#{content_type}'"} | query_params]
      else
        query_params
      end

    "#{@base_url}/me/drive/root/search"
    |> get(
      query: query_params,
      headers: auth_headers(access_token)
    )
    |> handle_response()
    |> case do
      {:ok, %{"value" => files}} -> {:ok, %{"files" => files}}
      error -> error
    end
  end
end
