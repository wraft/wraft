defmodule WraftDocWeb.Api.V1.PipeStageView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.ContentTypeView
  alias WraftDocWeb.Api.V1.DataTemplateView
  alias WraftDocWeb.Api.V1.FormMappingView
  alias WraftDocWeb.Api.V1.StateView

  def render("stage.json", %{stage: stage}) do
    %{
      id: stage.id,
      content_type:
        render_one(stage.content_type, ContentTypeView, "c_type_and_fields.json", as: :c_type),
      data_template:
        render_one(stage.data_template, DataTemplateView, "create.json", as: :d_template),
      state: render_one(stage.state, StateView, "create.json", as: :state),
      form_mapping:
        render_one(stage.form_mapping, FormMappingView, "show.json", as: :form_mapping),
      inserted_at: stage.inserted_at,
      updated_at: stage.updated_at
    }
  end

  def render("delete.json", %{stage: stage}) do
    %{
      id: stage.id,
      inserted_at: stage.inserted_at,
      updated_at: stage.updated_at
    }
  end
end
