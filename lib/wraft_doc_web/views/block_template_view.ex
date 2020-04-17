defmodule WraftDocWeb.Api.V1.BlockTemplateView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("block_template.json", %{block_template: block_template}) do
    %{
      id: block_template.uuid,
      title: block_template.title,
      body: block_template.body,
      serialised: block_template.serialised,
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
        render_many(block_templates, BlockTemplateView, "block_template.json", as: :block_template),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
