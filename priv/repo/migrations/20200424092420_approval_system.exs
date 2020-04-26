defmodule WraftDoc.Repo.Migrations.ApprovalSystem do
  use Ecto.Migration

  def change do
    create table(:approval_system) do
      add(:uuid, :uuid, null: false)
      add(:instance_id, references(:content, on_delete: :nilify_all))
      add(:pre_state_id, references(:state, on_delete: :nilify_all))
      add(:post_state_id, references(:state, on_delete: :nilify_all))
      add(:approver_id, references(:user, on_delete: :nilify_all))
      add(:user_id, references(:user, on_delete: :nilify_all))
      add(:organisation_id, references(:organisation, on_delete: :nilify_all))
      timestamps()
    end
  end
end
