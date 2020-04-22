defmodule WraftDoc.Repo.Migrations.RenameReplayCountFieldInCommentTable do
  use Ecto.Migration

  def up do
    rename(table(:comment), :replay_count, to: :reply_count)
  end

  def down do
    rename(table(:comment), :reply_count, to: :replay_count)
  end
end
