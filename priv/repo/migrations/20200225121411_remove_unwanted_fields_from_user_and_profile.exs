defmodule WraftDoc.Repo.Migrations.RemoveUnwantedFieldsFromUserAndProfile do
  use Ecto.Migration

  def up do
    alter table(:user) do
      remove(:mobile)
    end

    alter table(:basic_profile) do
      add(:timezone, :string)
    end
  end

  def down do
    alter table(:user) do
      add(:mobile, :string)
    end

    alter table(:basic_profile) do
      remove(:timezone)
    end
  end
end
