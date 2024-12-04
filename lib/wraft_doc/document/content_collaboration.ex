defmodule WraftDoc.Document.ContentCollaboration do
  @moduledoc """
  The Content Collaboration Model.
  """
  use WraftDoc.Schema

  @roles [:suggestor, :viewer]
  @fields [:roles, :content_id, :state_id, :user_id, :guest_user_id]

  schema "content_collaboration" do
    field(:roles, Ecto.Enum, values: @roles)
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
      name: :content_collab_user_state_content_unique_index,
      message: "already exist"
    )
  end
end
