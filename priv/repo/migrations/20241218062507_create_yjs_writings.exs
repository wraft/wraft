defmodule WraftDoc.Repo.Migrations.CreateYjsWritings do
  use Ecto.Migration

  def change do
    create table("yjs-writings") do
      add(:value, :binary)
      add(:version, :string)
      add(:content_id, :binary_id)
      # add :content_id, references(:content, type: :uuid, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create(index("yjs-writings", [:content_id, :version]))
  end
end
