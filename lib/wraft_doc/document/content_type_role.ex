defmodule WraftDoc.Document.ContentTypeRole do
  @moduledoc """
    This is the ContentTypeRole module
  """
  use WraftDoc.Schema

  alias WraftDoc.{Account.Role, Document.ContentType}

  schema "content_type_role" do
    belongs_to(:content_type, ContentType)
    belongs_to(:role, Role)

    timestamps()
  end

  # TODO write tests for changeset
  def changeset(content_type_role, attrs \\ %{}) do
    content_type_role
    |> cast(attrs, [:content_type_id, :role_id])
    |> validate_required([:role_id])
  end
end
