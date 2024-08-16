defmodule WraftDoc.Repo.Migrations.AddIsDisabledToFieldType do
  use Ecto.Migration

  def up do
    alter table(:field_type) do
      add(:is_disabled, :boolean, default: true)
    end

    execute("UPDATE field_type SET is_disabled = TRUE WHERE is_disabled IS NULL")
  end

  def down do
    alter table(:field_type) do
      remove(:is_disabled)
    end
  end
end
