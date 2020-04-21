defmodule WraftDoc.Repo.Migrations.AddTexChart do
  use Ecto.Migration

  def change do
    alter table(:block) do
      add(:tex_chart, :string)
    end
  end
end
