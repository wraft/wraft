defmodule WraftDoc.Repo.Migrations.AddBlockUrl do
  use Ecto.Migration

  def change do
    alter table(:block) do
      add(:pdf_url, :string)
    end
  end
end
