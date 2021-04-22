defmodule WraftDoc.Repo.Migrations.AddEditableInstance do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:editable, :boolean, default: true)
    end
  end
end
