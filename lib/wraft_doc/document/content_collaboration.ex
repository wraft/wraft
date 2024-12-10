defmodule WraftDoc.Document.ContentCollaboration do
  @moduledoc """
  The Content Collaboration Model.
  """
  use WraftDoc.Schema

  @roles [:suggestor, :viewer]
  @fields [:role, :content_id, :state_id, :user_id, :guest_user_id]

  schema "content_collaboration" do
    field(:role, Ecto.Enum, values: @roles)
    field(:status, Ecto.Enum, values: [:pending, :accepted], default: :pending)
    belongs_to(:content, WraftDoc.Document.Instance)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:guest_user, WraftDoc.Account.GuestUser)
    belongs_to(:user, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(content_collaboration, attrs) do
    content_collaboration
    |> cast(attrs, @fields)
    |> validate_required(@fields -- [:guest_user_id, :user_id])
    |> unique_constraint(@fields,
      name: :content_collaboration_content_id_guest_user_id_state_id_index,
      message: "content collaborator already exist"
    )
  end

  def status_update_changeset(content_collaboration, attrs) do
    content_collaboration
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end

  def role_update_changeset(content_collaboration, attrs) do
    content_collaboration
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end
end
