defmodule WraftDoc.Repo.Migrations.RejecedTime do
  use Ecto.Migration

  def change do
    alter table(:instance_approval_system) do
      add(:rejected_at, :naive_datetime)
      timestamps()
    end
  end
end
