defmodule WraftDoc.Repo.Migrations.AddThemeIdToContentType do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:content_type) do
      add(:theme_id, references(:theme, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end
end
