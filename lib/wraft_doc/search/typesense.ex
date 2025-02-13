defmodule WraftDoc.Search.Typesense do
  @moduledoc """
  Handles operations for interacting with Typesense, including creating collections,
  indexing documents, searching, and managing stored documents.
  """

  alias WraftDoc.Repo
  alias WraftDoc.Search.Encoder

  @doc """
  Creates a new collection in Typesense based on the provided schema.
  """
  @spec create_collection(map()) :: {:ok, map()} | {:error, any()}
  def create_collection(schema) do
    ExTypesense.create_collection(schema)
  end

  @doc """
  Creates a document in Typesense.
  """
  @spec create_document(map()) :: {:ok, map()} | {:error, any()}
  def create_document(document) do
    document = Encoder.to_document(document)
    ExTypesense.create_document(document)
  end

  @doc """
  Retrieves a document from Typesense by ID and collection name.
  """
  @spec get_document(String.t() | integer(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_document(id, collection_name) do
    ExTypesense.get_document(collection_name, to_string(id))
  end

  @doc """
  Updates a document in Typesense.
  """
  @spec update_document(map()) :: {:ok, map()} | {:error, any()}
  def update_document(document) do
    document = Encoder.to_document(document)
    ExTypesense.upsert_document(document)
  end

  @doc """
  Deletes a document from a collection in Typesense based on its ID.
  """
  @spec delete_document(String.t() | integer(), String.t()) :: {:ok, map()} | {:error, any()}
  def delete_document(id, collection_name) do
    query = %{filter_by: "id: #{id}"}
    ExTypesense.delete_documents_by_query(collection_name, query)
  end

  @doc """
  Initializes collections in Typesense based on schemas and reindexes existing data.
  """
  @spec initialize() :: :ok
  def initialize do
    collections = [
      {WraftDoc.Document.Theme, "theme"},
      {WraftDoc.Document.ContentType, "content_type"},
      {WraftDoc.Document.DataTemplate, "data_template"},
      {WraftDoc.Document.Layout, "layout"},
      {WraftDoc.Enterprise.Flow, "flow"}
    ]

    Enum.each(collections, fn {schema, collection_name} ->
      collection(schema, collection_name)
    end)
  end

  defp collection(schema, collection_name) do
    ExTypesense.Collection.drop_collection(collection_name)
    create_collection(schema)
    reindex_data(schema, collection_name)
  end

  @spec reindex_data(module(), String.t()) :: :ok | {:error, any()}
  defp reindex_data(schema, collection_name) do
    records = Repo.all(schema)
    documents = Enum.map(records, &Encoder.to_document/1)

    ExTypesense.index_multiple_documents(%{collection_name: collection_name, documents: documents})
  end

  @doc """
  Performs a search query across multiple collections or a specific collection in Typesense.

  ## Options
    - `query_by`: The fields to query against.
    - `filter_by`: A filter condition for refining search results.
    - `sort_by`: Sort order for results.
    - `page`: Pagination parameter.
    - `per_page`: Number of results per page.
    - `prefix`: Enables prefix-based searching.

  If no collection name is provided, the search is executed across predefined collections.
  """
  def x_search(params, org_id \\ nil) do
    # org_id = conn.assigns[:current_user].current_org_id
    query = Map.get(params, "query", "")
    collection = Map.get(params, "collection")

    opts =
      Enum.reduce(WraftDoc.Search.Presets.default_search_opts(), %{}, fn {key, default_value},
                                                                         acc ->
        param_value = Map.get(params, Atom.to_string(key))
        Map.put(acc, key, param_value || default_value)
      end)

    opts = Map.put(opts, :filter_by, org_id)

    case search(query, collection, opts) do
      {:ok, results} ->
        results

      # render(conn, "search.json", results: results)

      {:error, reason} ->
        reason
        # conn
        # |> put_status(:bad_request)
        # |> json(%{error: reason})
    end
  end

  @spec search(String.t(), String.t() | nil, keyword()) :: {:ok, map()} | {:error, any()}
  def search(query, collection_name \\ nil, opts \\ []) do
    collection_names = ["content_type", "theme", "layout", "flow", "data_template"]

    if is_nil(collection_name) do
      searches =
        Enum.map(collection_names, fn col ->
          %{
            collection: col,
            q: query,
            query_by: opts[:query_by]
          }
        end)

      ExTypesense.multi_search(searches)
    else
      search_params = %{
        collection: collection_name,
        q: query,
        query_by: opts[:query_by],
        filter_by: opts[:filter_by],
        sort_by: opts[:sort_by],
        page: opts[:page],
        per_page: opts[:per_page],
        prefix: Keyword.get(opts, :prefix, true)
      }

      clean_search_params =
        search_params
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      ExTypesense.search(collection_name, clean_search_params)
    end
  end
end

%{
  prefix: true,
  sort_by: nil,
  q: "the",
  page: 1,
  filter_by: nil,
  per_page: 10,
  collection_name: "data_template",
  query_by: "title"
}
