defmodule WraftDoc.Repo.Migrations.AddCommentsMeta do
  use Ecto.Migration

  def change do
    alter table(:comment) do
      add(:meta, :jsonb)
    end
  end
end
