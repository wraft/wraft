defmodule WraftDoc.Repo.Migrations.AddExtraFieldsToFieldTypes do
  use Ecto.Migration

  def up do
    alter table(:field_type) do
      add(:description, :string)
    end
  end

  def down do
    alter table(:field_type) do
      remove(:description)
    end
  end
end
