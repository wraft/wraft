defmodule WraftDocWeb.Api.V1.FormMappingView do
  use WraftDocWeb, :view

  alias __MODULE__

  def render("create.json", %{form_mapping: form}) do
    %{
      id: form.id,
      form_id: form.form_id,
      inserted_at: form.inserted_at,
      updated_at: form.updated_at,
      pipe_stage_id: form.pipe_stage_id,
      mapping: render_many(form.mapping, FormMappingView, "mapping.json", as: :mapping)
    }
  end

  def render("show.json", %{form_mapping: form}) do
    %{
      id: form.id,
      form_id: form.form_id,
      inserted_at: form.inserted_at,
      updated_at: form.updated_at,
      pipe_stage_id: form.pipe_stage_id,
      mapping: render_many(form.mapping, FormMappingView, "mapping.json", as: :mapping)
    }
  end

  def render("mapping.json", %{mapping: mapping}) do
    %{
      id: mapping.id,
      source: mapping.source,
      destination: mapping.destination
    }
  end
end
