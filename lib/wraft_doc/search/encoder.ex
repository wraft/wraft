defprotocol WraftDoc.Search.Encoder do
  @moduledoc """
  Protocol defining the interface for converting records to Typesense documents.
  """
  alias WraftDoc.Repo

  @doc """
  Converts a struct to a map format.
  """
  @spec to_document(t()) :: map()
  def to_document(struct)
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Documents.Instance do
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo

  def to_document(%Instance{} = instance) do
    organisation_id =
      instance
      |> Repo.preload(:content_type)
      |> Map.get(:content_type, %{})
      |> case do
        %ContentType{organisation_id: org_id} -> org_id
        _ -> ""
      end

    %{
      content_id: to_string(instance.id),
      collection_name: "content",
      instance_id: instance.instance_id,
      raw: instance.raw,
      name: instance.serialized["title"],
      serialized: Jason.encode!(instance.serialized),
      # document_type: instance.document_type,
      meta: Jason.encode!(instance.meta),
      type: instance.type,
      organisation_id: to_string(organisation_id),
      editable: instance.editable,
      allowed_users: instance.allowed_users,
      approval_status: instance.approval_status,
      creator_id: to_string(instance.creator_id),
      content_type_id: to_string(instance.content_type_id),
      state_id: to_string(instance.state_id),
      vendor_id: to_string(instance.vendor_id),
      inserted_at: instance.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at: instance.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.ContentTypes.ContentType do
  def to_document(%WraftDoc.ContentTypes.ContentType{} = content_type) do
    %{
      content_type_id: to_string(content_type.id),
      collection_name: "content_type",
      name: content_type.name,
      description: content_type.description,
      color: content_type.color,
      prefix: content_type.prefix,
      layout_id: to_string(content_type.layout_id),
      flow_id: to_string(content_type.flow_id),
      theme_id: to_string(content_type.theme_id),
      organisation_id: to_string(content_type.organisation_id) || "",
      creator_id: to_string(content_type.creator_id),
      inserted_at:
        content_type.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at: content_type.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.DataTemplates.DataTemplate do
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Repo

  def to_document(%DataTemplate{} = data_template) do
    organisation_id =
      data_template
      |> Repo.preload(:content_type)
      |> Map.get(:content_type, %{})
      |> case do
        %ContentType{organisation_id: org_id} -> org_id
        _ -> ""
      end

    %{
      data_template_id: to_string(data_template.id),
      collection_name: "data_template",
      name: data_template.title,
      title_template: data_template.title_template,
      data: data_template.data,
      serialized: Jason.encode!(data_template.serialized),
      content_type_id: to_string(data_template.content_type_id),
      creator_id: to_string(data_template.creator_id),
      organisation_id: to_string(organisation_id),
      inserted_at:
        data_template.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at:
        data_template.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end
end

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Layouts.Layout do
  def to_document(%WraftDoc.Layouts.Layout{} = layout) do
    %{
      layout_id: to_string(layout.id),
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

defimpl WraftDoc.Search.Encoder, for: WraftDoc.Themes.Theme do
  def to_document(%WraftDoc.Themes.Theme{} = theme) do
    %{
      theme_id: to_string(theme.id),
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
      flow_id: to_string(flow.id),
      collection_name: "flow",
      name: flow.name,
      controlled: flow.controlled,
      creator_id: to_string(flow.creator_id),
      organisation_id: to_string(flow.organisation_id),
      inserted_at: flow.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
      updated_at: flow.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end

  defimpl WraftDoc.Search.Encoder, for: WraftDoc.Pipelines.Pipeline do
    def to_document(%WraftDoc.Pipelines.Pipeline{} = pipeline) do
      %{
        pipeline_id: to_string(pipeline.id),
        collection_name: "pipeline",
        name: pipeline.name,
        api_route: pipeline.api_route,
        source: pipeline.source,
        source_id: pipeline.source_id,
        stages_count: pipeline.stages_count,
        creator_id: to_string(pipeline.creator_id),
        organisation_id: to_string(pipeline.organisation_id),
        inserted_at:
          pipeline.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
        updated_at: pipeline.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
      }
    end
  end

  defimpl WraftDoc.Search.Encoder, for: WraftDoc.Blocks.Block do
    def to_document(%WraftDoc.Blocks.Block{} = block) do
      %{
        block_id: to_string(block.id),
        collection_name: "block",
        name: block.name,
        description: block.description,
        btype: block.btype,
        dataset: Jason.encode!(block.dataset),
        input: block.input,
        file_url: block.file_url,
        api_route: block.api_route,
        endpoint: block.endpoint,
        tex_chart: block.tex_chart,
        creator_id: to_string(block.creator_id),
        organisation_id: to_string(block.organisation_id),
        inserted_at: block.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
        updated_at: block.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
      }
    end
  end

  defimpl WraftDoc.Search.Encoder, for: WraftDoc.Forms.Form do
    def to_document(%WraftDoc.Forms.Form{} = form) do
      %{
        form_id: to_string(form.id),
        collection_name: "form",
        name: form.name,
        description: form.description,
        prefix: form.prefix,
        status: to_string(form.status),
        creator_id: to_string(form.creator_id),
        organisation_id: to_string(form.organisation_id),
        inserted_at: form.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(),
        updated_at: form.updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
      }
    end
  end
end
