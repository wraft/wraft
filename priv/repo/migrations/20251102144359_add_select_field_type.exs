defmodule WraftDoc.Repo.Migrations.AddSelectFieldType do
  use Ecto.Migration
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Repo
  import Ecto.Query

  def up do
    # Check if "Select" field type already exists
    existing = Repo.one(from(ft in FieldType, where: ft.name == "Select", select: 1))

    if is_nil(existing) do
      # Insert "Select" field type if it doesn't exist
      Repo.insert_all(FieldType, [
        %{
          name: "Select",
          meta: %{"allowed validations" => ["required", "options"]},
          description: "A select field for single-choice selections",
          inserted_at: NaiveDateTime.local_now(),
          updated_at: NaiveDateTime.local_now()
        }
      ])
    end
  end

  def down do
    # Remove "Select" field type
    Repo.delete_all(from(ft in FieldType, where: ft.name == "Select"))
  end
end
