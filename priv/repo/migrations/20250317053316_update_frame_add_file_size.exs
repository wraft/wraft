defmodule WraftDoc.Repo.Migrations.UpdateFrameAddFileSize do
  use Ecto.Migration

  def up do
    rename(table(:frame), :frame_file, to: :file_size)
  end

  def down do
    rename(table(:frame), :file_size, to: :frame_file)
  end
end
