defmodule WraftDoc.ExAudit.Version do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @foreign_key_type :binary_id
  schema "ex_audit_version" do
    # The patch in Erlang External Term Format
    field(:patch, ExAudit.Type.Patch)
    field(:entity_id, Ecto.UUID)

    # name of the table the entity is in
    field(:entity_schema, ExAudit.Type.Schema)

    # type of the action that has happened to the entity (created, updated, deleted)
    field(:action, ExAudit.Type.Action)
    field(:recorded_at, :utc_datetime_usec)

    # was this change part of a rollback?
    field(:rollback, :boolean, default: false)

    belongs_to(:user, WraftDoc.Account.User)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:patch, :entity_id, :entity_schema, :action, :recorded_at, :rollback])
    |> cast(params, [:user_id])
  end
end
