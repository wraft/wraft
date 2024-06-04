defmodule WraftDoc.Repo.Migrations.AddDefaultOrderingForFormFields do
  @moduledoc """
  Script for adding default ordering for existing form fields

  mix run priv/repo/data/migrations/add_default_ordering_for_form_fields.exs
  """
  require Logger
  alias WraftDoc.Forms.FormField
  alias WraftDoc.Repo

  Logger.info("Starting default ordering update for FormField records")

  FormField
  |> Repo.all()
  # Group form fields by form_id
  |> Enum.group_by(& &1.form_id)
  |> Enum.each(fn {form_id, form_fields} ->
    Logger.info("Form #{form_id} has #{length(form_fields)} form fields")

    form_fields
    # Sort the form fields by inserted_at
    |> Enum.sort_by(& &1.inserted_at)
    # Assign a default ordering to each form field
    |> Enum.with_index(1)
    |> Enum.map(fn {form_field, order} ->
      # Update the form field with the default ordering
      Logger.info("Updating order for form field with id: #{form_field.id}")
      Repo.update!(FormField.order_update_changeset(form_field, %{order: order}))
    end)
  end)

  Logger.info("Default ordering update completed")
end
