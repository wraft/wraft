defmodule WraftDoc.Repo.Migrations.AddUniqueIndexToContentTypeFieldTable do
  use Ecto.Migration

  def change do
    create(
      unique_index(:content_type_field, [:name, :content_type_id, :field_type_id],
        name: :content_type_field_unique_index
      )
    )
  end
end
