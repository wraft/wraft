defmodule WraftDoc.SystemBackups.Event do
  @moduledoc """
  Audit record for backup downloads: token mints and every allowed or
  denied stream attempt, with actor, IP, and user agent. The moment
  all-tenant data leaves the perimeter is the highest-value thing to
  audit (R7); denied attempts are the interesting ones.
  """
  use WraftDoc.Schema

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.SystemBackups.Backup

  @events ~w(download_authorized download_allowed download_denied)

  schema "system_backup_events" do
    field(:event, :string)
    field(:detail, :string)
    field(:ip, :string)
    field(:user_agent, :string)

    belongs_to(:backup, Backup)
    belongs_to(:admin, InternalUser)

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event, :detail, :ip, :user_agent, :backup_id, :admin_id])
    |> validate_required([:event])
    |> validate_inclusion(:event, @events)
  end
end
