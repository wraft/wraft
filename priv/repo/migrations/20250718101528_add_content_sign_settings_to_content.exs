defmodule WraftDoc.Repo.Migrations.AddContentSignSettingsToContent do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:content_sign_settings, :map)
    end
  end
end
