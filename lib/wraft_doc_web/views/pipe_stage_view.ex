defmodule WraftDocWeb.Api.V1.PipeStageView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{ContentTypeView, DataTemplateView, StateView}

  def render("stage.json", %{stage: stage}) do
    %{
      id: stage.uuid,
      content_type:
        render_one(stage.content_type, ContentTypeView, "c_type_and_fields.json", as: :c_type),
      data_template:
        render_one(stage.data_template, DataTemplateView, "create.json", as: :d_template),
      state: render_one(stage.state, StateView, "create.json", as: :state),
      inserted_at: stage.inserted_at,
      updated_at: stage.updated_at
    }
  end

  def render("delete.json", %{stage: stage}) do
    %{
      id: stage.uuid,
      inserted_at: stage.inserted_at,
      updated_at: stage.updated_at
    }
  end
end
