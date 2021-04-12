defmodule WraftDoc.Repo.Migrations.ChangeBlockTemlateSerialisedFieldToText do
  use Ecto.Migration

  def up do
    alter table(:block_template) do
      modify(:serialised, :text)
    end
  end

  def down do
    alter table(:block_template) do
      modify(:serialised, :string)
    end
  end
end
