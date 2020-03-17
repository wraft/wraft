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
    field(:serialized, :map, default: %{})
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)

    has_many(:build_histories, WraftDoc.Document.Instance.History, foreign_key: :content_id)
    timestamps()
  end

  def changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [:instance_id, :raw, :serialized])
    |> validate_required([:instance_id, :raw, :serialized])
    |> unique_constraint(:instance_id,
      message: "Instance with the ID exists.!",
      name: :content_organisation_unique_index
    )
  end

  def update_changeset(%Instance{} = instance, attrs \\ %{}) do
    instance
    |> cast(attrs, [:instance_id, :raw, :serialized, :state_id])
    |> validate_required([:instance_id, :raw, :serialized, :state_id])
    |> unique_constraint(:instance_id,
      message: "Instance with the ID exists.!",
      name: :content_organisation_unique_index
    )
  end
end
