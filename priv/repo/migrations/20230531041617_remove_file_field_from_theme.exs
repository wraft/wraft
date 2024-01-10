defmodule WraftDoc.Repo.Migrations.RemoveFileFieldFromTheme do
  use Ecto.Migration

  def change do
    alter table(:theme) do
      remove(:file)
    end
  end
end
