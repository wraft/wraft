defmodule WraftDoc.Repo.Migrations.AddTableFieldType do
  use Ecto.Migration
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Repo

  def up do
    table_field_type = %{
      name: "Table",
      meta: %{"allowed validations" => ["required"]},
      description: "A table field with rows and columns",
      inserted_at: NaiveDateTime.local_now(),
      updated_at: NaiveDateTime.local_now()
    }

    Repo.insert_all(FieldType, [table_field_type])
  end

  def down do
    execute("DELETE FROM field_type WHERE name = 'Table'")
  end
end
