defmodule WraftDoc.Repo.Migrations.AddInternalUserSessionFields do
  use Ecto.Migration

  def change do
    alter table(:internal_user) do
      add(:session_epoch, :integer, default: 0, null: false)
    end
  end
end
