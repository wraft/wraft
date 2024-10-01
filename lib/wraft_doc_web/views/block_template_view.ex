defmodule WraftDocWeb.Api.V1.BlockTemplateView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.UserView

  def render("block_template.json", %{block_template: block_template}) do
    %{
      id: block_template.id,
      title: block_template.title,
      body: block_template.body,
      serialized: block_template.serialized,
      creator: render_one(block_template.creator, UserView, "user_id_and_name.json", as: :user),
      inserted_at: block_template.inserted_at,
      updated_at: block_template.updated_at
    }
  end

  def render("index.json", %{
        block_templates: block_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      block_templates:
        render_many(block_templates, BlockTemplateView, "block_template.json",
          as: :block_template
        ),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
