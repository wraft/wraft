defmodule WraftDoc.Search.Typesense do
  @moduledoc """
  Handles operations for Typesense
  """

  alias WraftDoc.Search.Encoder

  def create_collection(schema) do
    ExTypesense.create_collection(schema)
  end

  def create_document(document, collection_name) do
    document = Encoder.to_document(document)
    ExTypesense.create_document(document)
  end

  def get_document(id, collection_name) do
    ExTypesense.get_document(collection_name, to_string(id))
  end

  def update_document(document, collection_name) do
    document = Encoder.to_document(document)
    ExTypesense.upsert_document(document)
  end

  def delete_document(id, collection_name) do
    query = %{filter_by: "id: #{id}"}
    ExTypesense.delete_documents_by_query(collection_name, query)
  end

  def search(query) do
    collection_names = ["content_type", "theme", "layout", "flow", "data_template"]

    searches =
      Enum.map(collection_names, fn collection_name ->
        %{collection: collection_name, q: query, query_by: "name"}
      end)

    ExTypesense.multi_search(searches)
  end
end
