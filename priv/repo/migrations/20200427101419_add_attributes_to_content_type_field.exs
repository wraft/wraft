defmodule WraftDoc.Repo.Migrations.AddAttributesToContentTypeField do
  use Ecto.Migration

  def change do
    alter table(:content_type_field) do
      add(:attributes, :jsonb)
    end
  end
end
