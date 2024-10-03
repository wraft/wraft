defmodule WraftDoc.Repo.Migrations.CreateExAuditVersionTable do
  use Ecto.Migration

  def change do
    create table(:ex_audit_version) do
      # The patch in Erlang External Term Format
      add(:patch, :binary)
      add(:entity_id, :uuid)

      # name of the table the entity is in
      add(:entity_schema, :string)
      add(:action, :string)
      add(:recorded_at, :utc_datetime_usec)

      # was this change part of a rollback?
      add(:rollback, :boolean, default: false)

      # custom
      add(
        :user_id,
        references(:user,
          type: :uuid,
          column: :id,
          on_update: :update_all,
          on_delete: :nilify_all
        )
      )
    end
  end
end
