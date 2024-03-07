defmodule WraftDoc.Repo.Migrations.InstanceTransitionLog do
  use Ecto.Migration

  def change do
    create table(:instance_transition_log, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:review_status, :string)
      add(:reviewed_at, :naive_datetime)
      add(:from_state_id, references(:state, type: :uuid, on_delete: :nilify_all))
      add(:to_state_id, references(:state, type: :uuid, on_delete: :nilify_all))
      add(:reviewer_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:instance_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end
  end
end
