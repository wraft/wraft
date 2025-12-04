defmodule WraftDocWeb.Api.V1.FormEntryView do
  use WraftDocWeb, :view

  alias __MODULE__

  def render("form_entry.json", %{form_entry: form_entry, trigger_response: trigger_response}) do
    "form_entry.json"
    |> render(%{form_entry: form_entry})
    |> Map.merge(%{
      trigger_id: trigger_response.trigger_id,
      pipeline_id: trigger_response.pipeline_id
    })
  end

  def render("form_entry.json", %{form_entry: form_entry}) do
    %{
      id: form_entry.id,
      form_id: form_entry.form_id,
      user_id: form_entry.user_id,
      data: form_entry.data,
      status: form_entry.status,
      inserted_at: form_entry.inserted_at,
      updated_at: form_entry.updated_at
    }
  end

  def render("index.json", %{
        form_entries: form_entries,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      entries: render_many(form_entries, FormEntryView, "form_entry.json", as: :form_entry),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
