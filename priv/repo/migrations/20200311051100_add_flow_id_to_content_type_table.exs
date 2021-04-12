defmodule WraftDoc.Repo.Migrations.AddFlowIdToContentTypeTable do
  use Ecto.Migration

  def up do
    alter table(:content_type) do
      add(:flow_id, references(:flow))
    end
  end

  def down do
    alter table(:content_type) do
      remove(:flow_id)
    end
  end
end
