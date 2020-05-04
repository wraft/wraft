defmodule WraftDocWeb.Api.V1.DataTemplateView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{ContentTypeView, UserView}

  def render("create.json", %{d_template: d_temp}) do
    %{
      id: d_temp.uuid,
      title: d_temp.title,
      title_template: d_temp.title_template,
      data: d_temp.data,
      inserted_at: d_temp.inserted_at,
      updated_at: d_temp.updated_at
    }
  end

  def render("index.json", %{
        data_templates: data_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      data_templates:
        render_many(data_templates, DataTemplateView, "d_temp_and_c_type.json", as: :d_template),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("d_temp_and_c_type.json", %{d_template: d_temp}) do
    %{
      id: d_temp.uuid,
      title: d_temp.title,
      title_template: d_temp.title_template,
      data: d_temp.data,
      inserted_at: d_temp.inserted_at,
      updated_at: d_temp.updated_at,
      content_type:
        render_one(d_temp.content_type, ContentTypeView, "content_type.json", as: :content_type)
    }
  end

  def render("show.json", %{d_template: d_temp}) do
    %{
      data_template: render_one(d_temp, DataTemplateView, "create.json", as: :d_template),
      content_type:
        render_one(d_temp.content_type, ContentTypeView, "content_type.json", as: :content_type),
      creator: render_one(d_temp.creator, UserView, "user.json", as: :user)
    }
  end

  def render("bulk.json", %{}) do
    %{
      info: "Data templates will be created soon"
    }
  end
end
