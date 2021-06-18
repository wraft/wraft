defmodule WraftDocWeb.Api.V1.CollectionFormFieldView do
  use WraftDocWeb, :view

  def render("show.json", %{collection_form_field: collection_form_field}) do
    %{
      id: collection_form_field.id,
      name: collection_form_field.name,
      description: collection_form_field.description
    }
  end

  def render("create.json", %{collection_form_field: collection_form_field}) do
    %{
      name: collection_form_field.name,
      description: collection_form_field.description
    }
  end
end
