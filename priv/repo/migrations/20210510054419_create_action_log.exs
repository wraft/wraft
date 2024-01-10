defmodule WraftDoc.Repo.Migrations.CreateActionLog do
  use Ecto.Migration

  def change do
    create table(:action_log, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:actor, :jsonb)
      add(:remote_ip, :string)
      add(:actor_agent, :string)
      add(:request_path, :string)
      add(:request_method, :string)
      add(:action, :string)
      add(:params, :jsonb)

      timestamps()
    end
  end
end
