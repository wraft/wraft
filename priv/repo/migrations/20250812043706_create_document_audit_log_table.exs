defmodule WraftDoc.Repo.Migrations.CreateDocumentAuditLogTable do
  use Ecto.Migration

  defmodule WraftDoc.Repo.Migrations.CreateDocumentAuditLogs do
    use Ecto.Migration

    def up do
      create table(:document_audit_logs, primary_key: false) do
        add(:id, :uuid, primary_key: true)

        add(:actor, :map, default: %{}, null: false)
        add(:action, :string, null: false)
        add(:remote_ip, :string)
        add(:actor_agent, :string)
        add(:request_path, :string)
        add(:request_method, :string)
        add(:params, :map, default: %{}, null: false)

        add(:document_id, references(:content, type: :uuid, on_delete: :delete_all))

        add(:user_id, references(:user, type: :uuid, on_delete: :nilify_all))

        timestamps()
      end
    end

    def down do
      drop(table(:document_audit_logs))
    end
  end
end
