defmodule WraftDoc.Repo.Migrations.ChangeSerilaisedColumnNameToSerialized do
  use Ecto.Migration

  def up do
    rename(table(:block_template), :serialised, to: :serialized)
  end

  def down do
    rename(table(:block_template), :serialized, to: :serialised)
  end
end
