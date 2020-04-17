defmodule WraftDoc.Repo.Migrations.ChangeBlockTemlateBodyFieldToText do
  use Ecto.Migration

  def up do
    alter table(:block_template) do
      modify(:body, :text)
    end
  end

  def down do
    alter table(:block_template) do
      modify(:body, :string)
    end
  end
end
