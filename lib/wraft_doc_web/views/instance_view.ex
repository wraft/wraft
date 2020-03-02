defmodule WraftDocWeb.Api.V1.InstanceView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{ContentTypeView, FlowView}

  def render("create.json", %{content: content}) do
    %{
      content: %{
        id: content.uuid,
        instance_id: content.instance_id,
        raw: content.raw,
        serialized: content.serialized,
        inserted_at: content.inserted_at,
        updated_at: content.updated_at
      },
      content_type:
        render_one(content.content_type, ContentTypeView, "content_type.json", as: :content_type),
      state: render_one(content.state, FlowView, "flow.json", as: :flow)
    }
  end
end
