defmodule WraftDoc.Repo.Migrations.CollectionForm do
  use Ecto.Migration

  def change do
    create table(:collection_form, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:title, :string)
      add(:description, :string)

      timestamps()
    end

    create table(:collection_form_field, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:description, :string)

      add(
        :collection_form_id,
        references(:collection_form, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end
  end
end
