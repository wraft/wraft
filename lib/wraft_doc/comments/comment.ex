defmodule WraftDoc.Comments.Comment do
  @moduledoc false

  use WraftDoc.Schema

  schema "comment" do
    field(:comment, :string)
    field(:is_parent, :boolean)
    field(:master, :string)
    field(:master_id, :string)
    field(:reply_count, :integer)
    field(:meta, :map)
    field(:state, Ecto.Enum, values: [:active, :archive], default: :active)
    field(:resolved?, :boolean, default: false)

    belongs_to(:resolver, WraftDoc.Account.User)
    belongs_to(:doc_version, WraftDoc.Documents.Instance.Version)
    belongs_to(:parent, WraftDoc.Comments.Comment)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(comment, attrs \\ %{}) do
    comment
    |> cast(attrs, [
      :comment,
      :is_parent,
      :master,
      :master_id,
      :parent_id,
      :resolver_id,
      :resolved?,
      :user_id,
      :doc_version_id,
      :organisation_id,
      :meta,
      :state
    ])
    |> validate_required([
      :comment,
      :is_parent,
      :master,
      :master_id,
      :user_id
    ])
  end

  def reply_count_changeset(comment, attrs \\ %{}) do
    comment
    |> cast(attrs, [:reply_count])
    |> validate_required([:reply_count])
  end
end
