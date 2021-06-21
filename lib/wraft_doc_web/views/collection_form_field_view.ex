defmodule WraftDocWeb.Api.V1.CollectionFormFieldView do
  use WraftDocWeb, :view

  def render("show.json", %{collection_form_field: collection_form_field}) do
    %{
      id: collection_form_field.id,
      name: collection_form_field.name,
      description: collection_form_field.description,
      field_type: collection_form_field.field_type,
      meta: collection_form_field.meta,
      inserted_at: collection_form_field.inserted_at,
      updated_at: collection_form_field.updated_at
    }
  end

  def render("create.json", %{collection_form_field: collection_form_field}) do
    %{
      id: collection_form_field.id,
      name: collection_form_field.name,
      description: collection_form_field.description,
      field_type: collection_form_field.field_type,
      meta: collection_form_field.meta,
      inserted_at: collection_form_field.inserted_at,
      updated_at: collection_form_field.updated_at
    }
  end
end
