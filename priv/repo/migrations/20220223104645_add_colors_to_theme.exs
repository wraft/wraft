defmodule WraftDoc.Repo.Migrations.AddColorsToTheme do
  use Ecto.Migration

  def change do
    alter table(:theme) do
      add(:body_color, :string)
      add(:primary_color, :string)
      add(:secondary_color, :string)
      add(:preview_file, :string)
      add(:default_theme, :boolean, default: false)
    end
  end
end
