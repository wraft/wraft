defmodule WraftDoc.Repo.Migrations.AddFileUrl do
  use Ecto.Migration

  def up do
    alter table(:block) do
      remove(:pdf_url)
      add(:file_url, :string)
    end
  end

  def down do
    alter table(:block) do
      remove(:file_url)
      add(:pdf_url, :string)
    end
  end
end
