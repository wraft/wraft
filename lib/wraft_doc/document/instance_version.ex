defmodule WraftDoc.Document.Instance.Version do
  @moduledoc """
    The instance version model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  import Ecto.Query
  alias WraftDoc.{Account.User, Document.ContentType, Document.Instance}

  defimpl Spur.Trackable, for: __MODULE__ do
    def actor(version), do: "#{version.author_id}"
    def object(version), do: "Version:#{version.id}"
    def target(_chore), do: nil

    def audience(%{content_id: id}) do
      from(u in User,
        join: i in Instance,
        where: i.id == ^id,
        join: ct in ContentType,
        on: i.content_type_id == ct.id,
        where: u.organisation_id == ct.organisation_id
      )
    end
  end

  schema "version" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:version_number, :integer)
    field(:raw, :string)
    field(:serialized, :map, default: %{})
    field(:naration, :string)
    belongs_to(:content, WraftDoc.Document.Instance)
    belongs_to(:author, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%Version{} = version, attrs \\ %{}) do
    version
    |> cast(attrs, [:version_number, :raw, :serialized, :content_id, :author_id])
    |> validate_required([:version_number, :raw, :serialized, :author_id])
  end
end
