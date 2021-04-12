defmodule WraftDoc.Repo.Migrations.AddUniqueConstraintErrorInBlockTable do
  use Ecto.Migration

  def up do
    create(
      unique_index(:block, [:name, :organisation_id], name: :block_organisation_unique_index)
    )
  end

  def down do
    drop(index(:block, [:name, :organisation_id], name: :block_organisation_unique_index))
  end
end
