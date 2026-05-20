defmodule WraftDoc.Repo.Migrations.AddExAuditVersionIndexes do
  use Ecto.Migration

  @moduledoc """
  Indexes for the admin Audit Logs page.

  - `recorded_at DESC` powers the default ORDER BY for the list view and
    the COUNT(*) over the same filtered range.
  - `entity_schema` powers the entity-type dropdown filter.
  - `user_id` speeds up the search join against `user(name, email)`.

  Without these, the audit page degrades to a full scan as
  `ex_audit_version` grows.
  """

  def change do
    create_if_not_exists(index(:ex_audit_version, ["recorded_at DESC"]))
    create_if_not_exists(index(:ex_audit_version, [:entity_schema]))
    create_if_not_exists(index(:ex_audit_version, [:user_id]))
  end
end
