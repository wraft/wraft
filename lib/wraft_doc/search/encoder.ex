defprotocol WraftDoc.Search.Encoder do
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
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Document.ContentType do
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
      collection_name: "content_type",
      name: content_type.name,
      description: content_type.description,
      color: content_type.color,
      prefix: content_type.prefix,
      layout_id: to_string(content_type.layout_id),
      flow_id: to_string(content_type.flow_id),
      theme_id: to_string(content_type.theme_id),
      organisation_id: to_string(content_type.organisation_id),
      creator_id: to_string(content_type.creator_id),
      inserted_at:
        content_type.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at: content_type.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end

  @doc """
  Returns the Typesense collection name for ContentType records.
  """
  def collection_name(_content_type), do: "content_types"
end
