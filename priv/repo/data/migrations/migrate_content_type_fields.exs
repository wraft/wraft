defmodule WraftDoc.Repo.Migrations.MigrateContentTypeFields do
  @moduledoc """
   Migrate existing data for content type field data from Field table to ContentTypeField table

    Script for populating the content type field data. You can run it as:

     mix run priv/repo/data/migrations/migrate_content_type_fields.exs
  """
  require Logger
  alias WraftDoc.ContentTypes.ContentTypeField
  alias WraftDoc.Documents.Field
  alias WraftDoc.Repo

  fields = Repo.all(Field)

  Logger.info(
    "Migrating #{Enum.count(fields)} fields from field table to content type field table"
  )

  {success_count, failure_count} =
    Enum.reduce(fields, {0, 0}, fn field, {success, failure} ->
      Logger.info("Starting migration of field with field id: #{field.id}")

      changeset =
        ContentTypeField.changeset(%ContentTypeField{}, %{
          content_type_id: field.content_type_id,
          field_id: field.id,
          inserted_at: field.inserted_at,
          updated_at: field.updated_at
        })

      case Repo.insert(changeset) do
        {:ok, _} ->
          Logger.info("Finished migration of field with field id: #{field.id}")
          {success + 1, failure}

        {:error, changeset} ->
          Logger.error("Failed migration of field with field id: #{field.id}",
            changeset: changeset
          )

          {success, failure + 1}
      end
    end)

  Logger.info("Total fields successfully migrated: #{success_count}")
  Logger.info("Total fields failed to migrate: #{failure_count}")
end
