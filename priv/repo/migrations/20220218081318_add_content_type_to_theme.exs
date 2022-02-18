defmodule WraftDoc.Repo.Migrations.AddContentTypeToTheme do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:theme) do
      add(
        :content_type_id,
        references(:content_type, type: :uuid, column: :id, on_delete: :nilify_all)
      )
    end
  end
end
