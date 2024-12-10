defprotocol WraftDoc.Search.Encoder do
  @moduledoc """
  Protocol defining the interface for converting records to Typesense documents.
  """

  @doc """
  Converts a struct to a map format.
  """
  @spec to_document(t()) :: map()
  def to_document(struct)
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Document.ContentType do
  def to_document(%WraftDoc.Document.ContentType{} = content_type) do
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
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Document.DataTemplate do
  def to_document(%WraftDoc.Document.DataTemplate{} = data_template) do
    %{
      id: to_string(data_template.id),
      collection_name: "data_template",
      title: data_template.title,
      title_template: data_template.title_template,
      data: data_template.data,
      serialized: Jason.encode!(data_template.serialized),
      content_type_id: to_string(data_template.content_type_id),
      creator_id: to_string(data_template.creator_id),
      inserted_at:
        data_template.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at:
        data_template.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Document.Layout do
  def to_document(%WraftDoc.Document.Layout{} = layout) do
    %{
      id: to_string(layout.id),
      collection_name: "layout",
      name: layout.name,
      description: layout.description,
      width: layout.width,
      height: layout.height,
      unit: layout.unit,
      slug: layout.slug,
      engine_id: to_string(layout.engine_id),
      creator_id: to_string(layout.creator_id),
      organisation_id: to_string(layout.organisation_id),
      inserted_at: layout.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at: layout.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Document.Theme do
  def to_document(%WraftDoc.Document.Theme{} = theme) do
    %{
      id: to_string(theme.id),
      collection_name: "theme",
      name: theme.name,
      font: theme.font,
      typescale: Jason.encode!(theme.typescale),
      body_color: theme.body_color,
      primary_color: theme.primary_color,
      secondary_color: theme.secondary_color,
      creator_id: to_string(theme.creator_id),
      organisation_id: to_string(theme.organisation_id),
      inserted_at: theme.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at: theme.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Enterprise.Flow do
  def to_document(%WraftDoc.Enterprise.Flow{} = flow) do
    %{
      id: to_string(flow.id),
      collection_name: "flow",
      name: flow.name,
      controlled: flow.controlled,
      creator_id: to_string(flow.creator_id),
      organisation_id: to_string(flow.organisation_id),
      inserted_at: flow.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at: flow.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end
end
