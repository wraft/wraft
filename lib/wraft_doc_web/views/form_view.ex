defmodule WraftDocWeb.Api.V1.FormView do
  use WraftDocWeb, :view

  alias __MODULE__
  alias WraftDocWeb.Api.V1.FieldTypeView
  alias WraftDocWeb.Api.V1.PipelineView

  def render("form.json", %{form: form}) do
    %{
      id: form.id,
      name: form.name,
      description: form.description,
      prefix: form.prefix,
      status: form.status,
      inserted_at: form.inserted_at,
      updated_at: form.updated_at,
      fields: render_many(form.form_fields, FormView, "field.json", as: :form_field),
      pipelines: render_many(form.pipelines, PipelineView, "pipeline.json", as: :pipeline)
    }
  end

  def render("field.json", %{form_field: %{field: field, validations: validations, order: order}})
      when is_map(field) do
    %{
      id: field.id,
      order: order,
      name: field.name,
      meta: field.meta,
      validations:
        Enum.map(validations, &%{validation: &1.validation, error_message: &1.error_message}),
      description: field.description,
      field_type: render_one(field.field_type, FieldTypeView, "field_type.json", as: :field_type)
    }
  end

  def render("simple_form.json", %{form: form}) do
    %{
      id: form.id,
      name: form.name,
      description: form.description,
      prefix: form.prefix,
      status: form.status,
      inserted_at: form.inserted_at,
      updated_at: form.updated_at
    }
  end

  def render("index.json", %{
        forms: forms,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      forms: render_many(forms, __MODULE__, "simple_form.json", as: :form),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  # Test this case while implementing show API
  def render("field_type.json", _), do: nil
end
