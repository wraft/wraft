defmodule WraftDoc.Repo.Migrations.CreateYjsWritings do
  use Ecto.Migration

  def change do
    create table("yjs-writings") do
      add :docName, :string
      add :value, :binary
      add :version, :string

      timestamps(type: :utc_datetime)
    end

    create index("yjs-writings", [:docName, :version])
  end
end
