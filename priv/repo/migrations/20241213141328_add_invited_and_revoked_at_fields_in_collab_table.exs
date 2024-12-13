defmodule WraftDoc.Repo.Migrations.AddInvitedAndRevokedAtFieldsInCollabTable do
  use Ecto.Migration

  def change do
    alter table(:content_collaboration) do
      add(:invited_by, references(:user, type: :uuid, on_delete: :nilify_all))
      add(:revoked_by, references(:user, type: :uuid, on_delete: :nilify_all))
      add(:revoked_at, :utc_datetime)
    end

    alter table(:user) do
      add(:guest, :boolean, default: false)
    end
  end
end
