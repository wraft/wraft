defmodule WraftDoc.Repo.Migrations.UpdateThemeAddFontId do
  @moduledoc false
  use Ecto.Migration

  def up do
    alter table(:theme) do
      add(:font_id, references(:fonts, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    create(index(:theme, [:font_id]))

    # Remove the old font string field
    alter table(:theme) do
      remove(:font)
    end
  end

  def down do
    alter table(:theme) do
      add(:font, :string)
    end

    drop(index(:theme, [:font_id]))

    alter table(:theme) do
      remove(:font_id)
    end
  end
end
