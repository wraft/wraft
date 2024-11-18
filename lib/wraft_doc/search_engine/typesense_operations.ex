defmodule WraftDoc.SearchEngine.TypesenseOperations do
  @moduledoc """
  Handles operations for Typesense
  """

  alias WraftDoc.Repo
  alias WraftDoc.SearchEngine.TypesenseIndex

  def create_document(attrs, schema) do
    with {:ok, document} <- create_repo_document(attrs, schema),
         {:ok, _response} <- ExTypesense.create_document(
          TypesenseIndex.collection_name(document),
          TypesenseIndex.to_document(document)
         ) do
      {:ok, document}
    else
      {:error, error} -> {:error, error}
    end
  end

  def get_document(id, schema) do
    struct = struct(schema)
    ExTypesense.get_document(TypesenseIndex.collection_name(struct), to_string(id))
  end

  def update_document(id, attrs, schema) do
    with {:ok, document} <- get_repo_document(id, schema),
         {:ok, updated_document} <- update_repo_document(document, attrs, schema),
         {:ok, _response} <- ExTypesense.upsert_document(
          TypesenseIndex.collection_name(updated_document),
          TypesenseIndex.to_document(updated_document)
         ) do
      {:ok, updated_document}
    else
      {:error, error} -> {:error, error}
    end
  end

  def delete_document(id, schema) do
    with {:ok, document} <- get_repo_document(id, schema),
         {:ok, _} <- Repo.delete(document),
         {:ok, _response} <- ExTypesense.delete_document(
          TypesenseIndex.collection_name(document),
           to_string(id)
         ) do
      {:ok, document}
    else
      {:error, error} -> {:error, error}
    end
  end

  def search_documents(query, schema, opts \\ []) do
    struct = struct(schema)
    collection_name = TypesenseIndex.collection_name(struct)

    search_params = %{
      q: query,
      query_by: Enum.join(search_fields_from_schema(struct), ","),
      per_page: Keyword.get(opts, :per_page, 10),
      page: Keyword.get(opts, :page, 1)
    }

    ExTypesense.search(collection_name, search_params)
  end

  def bulk_index_documents(documents) when is_list(documents) do
    case documents do
      [first | _] ->
        collection_name = TypesenseIndex.collection_name(first)
        documents_map = Enum.map(documents, &TypesenseIndex.to_document/1)
        ExTypesense.import_documents(collection_name, documents_map)

      [] ->
        {:ok, []}
    end
  end

  def setup_collection(schema) do
    struct = struct(schema)
    collection_name = TypesenseIndex.collection_name(struct)
    collection_schema = TypesenseIndex.collection_schema(struct)

    # First try to delete existing collection
    case ExTypesense.get_collection(collection_name) do
      {:ok, _} -> ExTypesense.delete_collection_alias(collection_name)
      _ -> :ok
    end

    # Create new collection
    ExTypesense.create_collection(collection_schema)
  end

  defp create_repo_document(attrs, schema) do
    schema
    |> struct()
    |> schema.changeset(attrs)
    |> Repo.insert()
  end

  defp get_repo_document(id, schema) do
    case Repo.get(schema, id) do
      nil -> {:error, :not_found}
      document -> {:ok, document}
    end
  end

  defp update_repo_document(document, attrs, schema) do
    document
    |> schema.changeset(attrs)
    |> Repo.update()
  end

  defp search_fields_from_schema(struct) do
    struct
    |> TypesenseIndex.collection_schema()
    |> Map.get(:fields)
    |> Enum.filter(&(&1.type == "string"))
    |> Enum.map(&(&1.name))
    |> Enum.reject(&(&1 in ["id", "inserted_at", "updated_at"]))
  end

  # defp convert_ids_to_binary(attrs) do
  #   attrs
  #   |> Enum.map(fn {key, value} ->
  #     case key do
  #       key when key in [:layout_id, :flow_id, :theme_id, :organisation_id, :creator_id] ->
  #         {key, Ecto.UUID.generate()}
  #       _ ->
  #         {key, value}
  #     end
  #   end)
  #   |> Map.new()
  # end
end
