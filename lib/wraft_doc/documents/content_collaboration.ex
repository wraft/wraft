defmodule WraftDoc.Documents.ContentCollaboration do
  @moduledoc """
  The Content Collaboration Model.
  """
  use WraftDoc.Schema

  @roles [:suggestor, :viewer, :editor]
  @fields [:role, :content_id, :state_id, :user_id, :invited_by_id]
  @statuses [:pending, :accepted, :revoked]

  schema "content_collaboration" do
    field(:role, Ecto.Enum, values: @roles)
    field(:status, Ecto.Enum, values: @statuses, default: :pending)
    field(:revoked_at, :utc_datetime)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:invited_by, WraftDoc.Account.User, foreign_key: :invited_by_id)
    belongs_to(:revoked_by, WraftDoc.Account.User, foreign_key: :revoked_by_id)
    timestamps()
  end

  def changeset(content_collaboration, attrs) do
    content_collaboration
    |> cast(attrs, @fields)
    |> validate_required(@fields -- [:user_id])
    |> unique_constraint(@fields,
      name: :content_collaboration_content_id_user_id_state_id_index,
      message: "This email has already been invited."
    )
  end

  def status_update_changeset(content_collaboration, attrs) do
    content_collaboration
    |> cast(attrs, [:status, :revoked_at, :revoked_by_id])
    |> validate_required([:status])
  end

  def role_update_changeset(content_collaboration, attrs) do
    content_collaboration
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end
end
