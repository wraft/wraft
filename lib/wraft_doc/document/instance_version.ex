defmodule WraftDoc.Document.Instance.Version do
  @moduledoc """
    The instance version model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "version" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:version_number, :integer)
    field(:raw, :string)
    field(:serialized, :map, default: %{})
    belongs_to(:content, WraftDoc.Document.Instance)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%Version{} = version, attrs \\ %{}) do
    version
    |> cast(attrs, [:version_number, :raw, :serialized])
    |> validate_required([:version_number])
  end
end
