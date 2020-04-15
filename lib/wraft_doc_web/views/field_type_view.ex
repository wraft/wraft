defmodule WraftDocWeb.Api.V1.FieldTypeView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("field_type.json", %{field_type: field_type}) do
    %{
      id: field_type.uuid,
      name: field_type.name,
      description: field_type.description,
      inserted_at: field_type.inserted_at,
      updated_at: field_type.updated_at
    }
  end

  def render("index.json", %{
        field_types: field_types,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      field_types: render_many(field_types, FieldTypeView, "field_type.json", as: :field_type),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
