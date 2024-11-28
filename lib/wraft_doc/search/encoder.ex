defprotocol WraftDoc.Search.Encoder do
  @moduledoc """
  Protocol defining the interface for converting records to Typesense documents.
  """

  @doc """
  Converts a struct to a map format .
  """
  @spec to_document(t()) :: map()
  def to_document(struct)
end

defimpl WraftDoc.Search.Encoder,
  for: [
    WraftDoc.Document.ContentType,
    WraftDoc.Document.DataTemplate,
    WraftDoc.Document.Layout,
    WraftDoc.Document.Theme,
    WraftDoc.Enterprise.Flow
  ] do
  @moduledoc """
  Handles conversion of schema for Typesense indexing.
  """

  alias WraftDoc.Document.{ContentType, DataTemplate, Layout, Theme}
  alias WraftDoc.Enterprise.Flow

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
      inserted_at: format_timestamp(content_type.inserted_at),
      updated_at: format_timestamp(content_type.updated_at)
    }
  end

  def to_document(%DataTemplate{} = data_template) do
    %{
      id: to_string(data_template.id),
      collection_name: "data_template",
      title: data_template.title,
      title_template: data_template.title_template,
      data: data_template.data,
      serialized: data_template.serialized,
      content_type_id: to_string(data_template.content_type_id),
      creator_id: to_string(data_template.creator_id),
      inserted_at: format_timestamp(data_template.inserted_at),
      updated_at: format_timestamp(data_template.updated_at)
    }
  end

  def to_document(%Layout{} = layout) do
    %{
      id: to_string(layout.id),
      collection_name: "layout",
      name: layout.name,
      description: layout.description,
      width: layout.width,
      height: layout.height,
      unit: layout.unit,
      slug: layout.slug,
      slug_file: layout.slug_file,
      screenshot: layout.screenshot,
      engine_id: to_string(layout.engine_id),
      creator_id: to_string(layout.creator_id),
      organisation_id: to_string(layout.organisation_id),
      inserted_at: format_timestamp(layout.inserted_at),
      updated_at: format_timestamp(layout.updated_at)
    }
  end

  def to_document(%Theme{} = theme) do
    %{
      id: to_string(theme.id),
      collection_name: "theme",
      name: theme.name,
      font: theme.font,
      typescale: theme.typescale,
      body_color: theme.body_color,
      primary_color: theme.primary_color,
      secondary_color: theme.secondary_color,
      preview_file: theme.preview_file,
      creator_id: to_string(theme.creator_id),
      organisation_id: to_string(theme.organisation_id),
      inserted_at: format_timestamp(theme.inserted_at),
      updated_at: format_timestamp(theme.updated_at)
    }
  end

  def to_document(%Flow{} = flow) do
    %{
      id: to_string(flow.id),
      collection_name: "flow",
      name: flow.name,
      controlled: flow.controlled,
      control_data: flow.control_data,
      creator_id: to_string(flow.creator_id),
      organisation_id: to_string(flow.organisation_id),
      inserted_at: format_timestamp(flow.inserted_at),
      updated_at: format_timestamp(flow.updated_at)
    }
  end

  defp format_timestamp(naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end
end
