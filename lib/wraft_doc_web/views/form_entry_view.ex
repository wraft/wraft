defmodule WraftDocWeb.Api.V1.FormEntryView do
  use WraftDocWeb, :view

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
end
