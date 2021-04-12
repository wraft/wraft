defmodule WraftDoc.Repo.Migrations.AddFieldsInBlock do
  use Ecto.Migration

  def change do
    alter table(:block) do
      add(:fields, :jsonb)
    end
  end
end
