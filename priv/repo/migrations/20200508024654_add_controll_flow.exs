defmodule WraftDoc.Repo.Migrations.AddControllFlow do
  use Ecto.Migration

  def change do
    alter table(:flow) do
      add(:controlled, :boolean, default: false)
      add(:control_data, :jsonb)
    end
  end
end
