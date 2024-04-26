defmodule WraftDoc.Repo.Migrations.AddSourceAndSourceIdToPipeline do
  use Ecto.Migration

  def change do
    alter table(:pipeline) do
      add(:source, :string)
      add(:source_id, :string)
    end
  end
end
