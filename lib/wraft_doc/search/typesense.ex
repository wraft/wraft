defmodule WraftDoc.Search.Typesense do
  @moduledoc """
  Handles operations for Typesense
  """

  alias WraftDoc.Search.Encoder

  def create_collection(schema) do
    ExTypesense.create_collection(Encoder.to_document(schema))
  end

  def create_document(document, collection_name) do
    document = Encoder.to_document(document)
    typesense_document = Map.merge(document, %{collection_name: "#{collection_name}"})
    ExTypesense.create_document(typesense_document)
  end

  def get_document(id, collection_name) do
    ExTypesense.get_document("#{collection_name}", to_string(id))
  end

  def update_document(document, collection_name) do
    typesense_document = Map.merge(document, %{collection_name: "#{collection_name}"})
    ExTypesense.update_document(typesense_document)
  end

  def delete_document(id, collection_name) do
    ExTypesense.delete_document({"#{collection_name}", id})
  end

  def search(collection_name, search_params) do
    ExTypesense.search(collection_name, search_params)
  end
end
