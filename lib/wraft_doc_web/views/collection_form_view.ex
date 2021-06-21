defmodule WraftDocWeb.Api.V1.CollectionFormView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.CollectionFormFieldView
  alias WraftDocWeb.Api.V1.CollectionFormView

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
      id: collection_form.id,
      title: collection_form.title,
      description: collection_form.description,
      inserted_at: collection_form.inserted_at,
      updated_at: collection_form.updated_at
    }
  end

  def render("collection_form.json", %{collection_form: collection_form}) do
    %{
      id: collection_form.id,
      title: collection_form.title,
      description: collection_form.description,
      inserted_at: collection_form.inserted_at,
      updated_at: collection_form.updated_at,
      collection_form_fields:
        render_many(collection_form.collection_form_fields, CollectionFormFieldView, "show.json",
          as: :collection_form_field
        )
    }
  end

  def render("index.json", %{
        collection_forms: collection_forms,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      collection_forms:
        render_many(collection_forms, CollectionFormView, "collection_form.json",
          as: :collection_form
        ),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
