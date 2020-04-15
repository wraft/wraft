defmodule WraftDoc.Repo.Migrations.AddProfileUuid do
  use Ecto.Migration

  def change do
    alter table(:basic_profile) do
      add(:uuid, :uuid)
    end
  end
end
