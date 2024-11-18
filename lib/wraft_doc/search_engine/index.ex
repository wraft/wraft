defprotocol WraftDoc.SearchEngine.Index do
  @moduledoc """
  Protocol defining the interface for converting records to Typesense documents.
  """

  @doc """
  Converts a struct to a map format suitable for Typesense indexing.
  """
  @spec to_document(t()) :: map()
  def to_document(struct)

  @doc """
  Returns the collection name for the given struct type.
  """
  @spec collection_name(t()) :: String.t()
  def collection_name(struct)

  @doc """
  Returns the schema configuration for the collection.
  """
  @spec collection_schema(t()) :: map()
  def collection_schema(struct)
end

defimpl WraftDoc.SearchEngine.Index, for: WraftDoc.Document.ContentType do
  @moduledoc """
  Implementation of the Index protocol for ContentType schema.
  Handles conversion of ContentType records for Typesense indexing.
  """

  alias WraftDoc.Document.ContentType

  @doc """
  Converts a ContentType struct to a map format suitable for Typesense indexing.
  """
  def to_document(%ContentType{} = content_type) do
    %{
      id: to_string(content_type.id),
      record_type: "content_type",
      name: content_type.name,
      description: content_type.description || "",
      color: content_type.color,
      prefix: content_type.prefix,
      layout_id: to_string(content_type.layout_id),
      flow_id: to_string(content_type.flow_id),
      theme_id: to_string(content_type.theme_id),
      organisation_id: to_string(content_type.organisation_id),
      creator_id: to_string(content_type.creator_id),
      inserted_at: DateTime.to_iso8601(content_type.inserted_at),
      updated_at: DateTime.to_iso8601(content_type.updated_at)
    }
  end

  @doc """
  Returns the Typesense collection name for ContentType records.
  """
  def collection_name(_content_type) do
    "content_types"
  end

  @doc """
  Returns the schema configuration for the ContentType collection.
  """
  def collection_schema(_content_type) do
    %{
      name: "content_types",
      fields: [
        %{name: "id", type: "string"},
        %{name: "record_type", type: "string"},
        %{name: "name", type: "string"},
        %{name: "description", type: "string", optional: true},
        %{name: "color", type: "string"},
        %{name: "prefix", type: "string"},
        %{name: "layout_id", type: "string"},
        %{name: "flow_id", type: "string"},
        %{name: "theme_id", type: "string"},
        %{name: "organisation_id", type: "string"},
        %{name: "creator_id", type: "string"},
        %{name: "inserted_at", type: "string"},
        %{name: "updated_at", type: "string"}
      ],
      default_sorting_field: "inserted_at"
    }
  end
end
