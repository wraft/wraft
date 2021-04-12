defmodule WraftDoc.Repo.Migrations.AddInputFieldToBlockTable do
  use Ecto.Migration

  def up do
    alter table(:block) do
      add(:input, :string)
    end
  end

  def down do
    alter table(:block) do
      remove(:input)
    end
  end
end
