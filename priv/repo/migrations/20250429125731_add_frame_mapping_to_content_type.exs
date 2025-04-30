defmodule WraftDoc.Repo.Migrations.AddFrameMappingToContentType do
  use Ecto.Migration

  def up do
    alter table(:content_type) do
      add(:frame_mapping, :jsonb)
    end
  end

  def down do
    alter table(:content_type) do
      remove(:frame_mapping)
    end
  end
end
