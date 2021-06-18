defmodule WraftDocWeb.Api.V1.CollectionFormView do
  use WraftDocWeb, :view

  def render("show.json", %{collection_form: collection_form}) do
    %{
      id: collection_form.id,
      title: collection_form.title,
      description: collection_form.description,
      inserted_at: collection_form.inserted_at,
      updated_at: collection_form.updated_at
    }
  end

  def render("create.json", %{collection_form: collection_form}) do
    %{
      title: collection_form.title,
      description: collection_form.description,
      inserted_at: collection_form.inserted_at,
      updated_at: collection_form.updated_at
    }
  end
end
