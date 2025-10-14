defmodule WraftDoc.Repo.Migrations.CreateDocumentAuditLogTable do
  use Ecto.Migration

  def up do
    create table(:document_audit_tiles, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:actor, :map, default: %{}, null: false)
      add(:action, :string, null: false)
      add(:message, :string)
      add(:metadata, :map, default: %{})

      add(:document_id, references(:content, type: :uuid, on_delete: :delete_all))
      add(:user_id, references(:user, type: :uuid, on_delete: :nilify_all))

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all))

      timestamps()
    end
  end

  def down do
    drop(table(:document_audit_tiles))
  end
end
