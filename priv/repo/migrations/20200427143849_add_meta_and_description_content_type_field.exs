defmodule WraftDoc.Repo.Migrations.AddMetaAndDescriptionContentTypeField do
  use Ecto.Migration

  def up do
    alter table(:content_type_field) do
      remove(:attributes)
      add(:meta, :jsonb)
      add(:description, :string)
    end
  end

  def down do
    alter table(:content_type_field) do
      add(:attributes, :string)
      remove(:meta, :jsonb)
      remove(:description, :string)
    end
  end
end
