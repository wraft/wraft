defmodule WraftDoc.Repo.Migrations.CreateIndexForDocumentInstanceTitle do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX instance_serialized_title_index ON content((serialized->'title'));")
  end

  def down do
    execute("DROP INDEX  instance_serialized_title_index;")
  end
end
