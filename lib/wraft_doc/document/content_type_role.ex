defmodule WraftDoc.Document.ContentTypeRole do
  @moduledoc """
    This is the ContentTypeRole module
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.{Account.Role, Document.ContentType}

  schema "content_type_role" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    belongs_to(:content_type, ContentType)
    belongs_to(:role, Role)

    timestamps()
  end

  def changeset(content_type_role, attrs \\ %{}) do
    content_type_role
    |> cast(attrs, [:content_type_id, :role_id])
    |> validate_required([:role_id])
  end
end
