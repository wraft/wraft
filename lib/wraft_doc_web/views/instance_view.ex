defmodule WraftDocWeb.Api.V1.InstanceView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{ContentTypeView, StateView, UserView}
  alias __MODULE__

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
      state: render_one(content.state, StateView, "create.json", as: :state)
    }
  end

  def render("instance.json", %{instance: instance}) do
    %{
      id: instance.uuid,
      instance_id: instance.instance_id,
      raw: instance.raw,
      serialized: instance.serialized,
      inserted_at: instance.inserted_at,
      updated_at: instance.updated_at
    }
  end

  def render("index.json", %{contents: contents}) do
    render_many(contents, InstanceView, "instance.json", as: :instance)
  end

  def render("show.json", %{instance: instance}) do
    %{
      content: render_one(instance, InstanceView, "instance.json", as: :instance),
      content_type:
        render_one(instance.content_type, ContentTypeView, "content_type.json", as: :content_type),
      state: render_one(instance.state, StateView, "create.json", as: :state),
      creator: render_one(instance.creator, UserView, "user.json", as: :user)
    }
  end
end
