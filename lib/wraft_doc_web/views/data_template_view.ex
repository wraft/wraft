defmodule WraftDocWeb.Api.V1.DataTemplateView do
  use WraftDocWeb, :view

  def render("create.json", %{d_template: d_temp}) do
    %{
      id: d_temp.uuid,
      tag: d_temp.tag,
      data: d_temp.data,
      inserted_at: d_temp.inserted_at,
      updated_at: d_temp.updated_at
    }
  end
end
