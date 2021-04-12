defmodule WraftDoc.Repo.Migrations.AddUniqueIndexToResourceTable do
  use Ecto.Migration

  def up do
    create(unique_index(:resource, [:category, :action], name: :resource_unique_index))
  end

  def down do
    drop(unique_index(:resource, [:category, :action], name: :resource_unique_index))
  end
end
