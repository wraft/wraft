defmodule WraftDoc.Repo.Migrations.AddLabel do
  use Ecto.Migration

  def change do
    alter table(:resource) do
      add(:label, :string)
    end
  end
end
