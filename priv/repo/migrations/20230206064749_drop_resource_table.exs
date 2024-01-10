defmodule WraftDoc.Repo.Migrations.DropResourceTable do
  use Ecto.Migration

  def change do
    drop(table(:resource))
  end
end
