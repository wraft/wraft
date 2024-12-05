defmodule WraftDoc.Search.Typesense do
  @moduledoc """
  Handles operations for Typesense
  """

  alias WraftDoc.Search.Encoder

  def create_collection(schema) do
    ExTypesense.create_collection(schema)
  end

  def create_document(document) do
    document = Encoder.to_document(document)
    ExTypesense.create_document(document)
  end

  def get_document(id, collection_name) do
    ExTypesense.get_document(collection_name, to_string(id))
  end

  def update_document(document) do
    document = Encoder.to_document(document)
    ExTypesense.upsert_document(document)
  end

  def delete_document(id, collection_name) do
    query = %{filter_by: "id: #{id}"}
    ExTypesense.delete_documents_by_query(collection_name, query)
  end

  def index_document(collection_name) do
    ExTypesense.index_multiple_documents(collection_name)
  end

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
        per_page: opts[:per_page]
      }

      search_params =
        if opts[:prefix] do
          Map.put(search_params, :prefix, true)
        else
          search_params
        end

      clean_search_params =
        Enum.into(Enum.reject(search_params, fn {_k, v} -> is_nil(v) end), %{})

      ExTypesense.search(collection_name, clean_search_params)
    end
  end
end
