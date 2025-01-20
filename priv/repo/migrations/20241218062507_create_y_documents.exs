defmodule WraftDoc.Repo.Migrations.CreateYDocuments do
  use Ecto.Migration

  def change do
    create table("y_documents") do
      add(:value, :binary)
      add(:version, :string)
      add(:content_id, :binary_id)
      # add :content_id, references(:content, type: :uuid, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create(index("y_documents", [:content_id, :version]))
  end
end
