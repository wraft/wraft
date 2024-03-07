defmodule WraftDoc.Document.ContentCollab do
  @moduledoc """
  The Counter model.
  """
  use WraftDoc.Schema

  @roles [:editor, :viewer, :commenter]
  @fields [:content_id, :state_id, :user_id]

  schema "content_collab" do
    field(:roles, Ecto.Enum, values: @roles)
    belongs_to(:content, WraftDoc.Document.Instance)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:user, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(content_collab, attrs) do
    content_collab
    |> cast(attrs, [:roles, :content_id, :state_id, :user_id])
    |> validate_required(@fields)
    |> unique_constraint(@fields,
      name: :content_collab_user_state_content_unique_index,
      message: "already exist"
    )
  end
end
