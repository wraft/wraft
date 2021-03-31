defmodule WraftDoc.Repo.Migrations.CreateLogTable do
  use Ecto.Migration

  def up do
    create table(:action_log) do
      add(:uuid, :uuid, null: false)
      add(:user_id, references(:user, on_delete: :nilify_all))
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

  def down do
    drop_if_exists(table(:action_log))
  end
end
