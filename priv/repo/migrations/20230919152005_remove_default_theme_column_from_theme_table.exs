defmodule WraftDoc.Repo.Migrations.RemoveDefaultThemeColumnFromThemeTable do
  use Ecto.Migration

  def up do
    alter table(:theme) do
      remove(:default_theme)
    end
  end

  def down do
    alter table(:theme) do
      add(:default_theme, :boolean, default: false)
    end
  end
end
