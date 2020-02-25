defmodule WraftDoc.Document.Instance do
  @moduledoc """
    The instance model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.Instance

  schema "content" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:instance_id, :string, null: false)
    field(:raw, :string)
    field(:serialized, {:array, :string}, default: %{})
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    timestamps()
  end

  def changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [:instance_id, :raw, :serialized, :content_type_id])
    |> validate_required([:instanec_id, :raw, :serialized, :content_type_id])
    |> unique_constraint(:instance_id,
      message: "Instance with the ID exists.!",
      name: :content_organisation_unique_index
    )
  end
end
