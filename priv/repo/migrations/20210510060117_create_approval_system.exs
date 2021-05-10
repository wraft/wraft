defmodule WraftDoc.Repo.Migrations.CreateApprovalSystem do
  use Ecto.Migration

  def change do
    create table(:approval_system, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:instance_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:pre_state_id, references(:state, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:post_state_id, references(:state, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:approver_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(:approved, :boolean, default: false)
      add(:approved_log, :naive_datetime)
      timestamps()
    end
  end
end
