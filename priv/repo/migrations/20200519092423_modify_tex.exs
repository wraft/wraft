defmodule WraftDoc.Repo.Migrations.ModifyTex do
  use Ecto.Migration

  def up do
    alter table(:block) do
      modify(:tex_chart, :text)
    end
  end

  def down do
    alter table(:block) do
      modify(:tex_chart, :string)
    end
  end
end
