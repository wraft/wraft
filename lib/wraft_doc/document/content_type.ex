defmodule WraftDoc.Document.ContentType do
  @moduledoc """
    The content type model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias WraftDoc.Account.User
  import Ecto.Query
  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: ContentType do
    def actor(content_type), do: "#{content_type.creator_id}"
    def object(content_type), do: "ContentType:#{content_type.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "content_type" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:description, :string)
    # field(:fields, :map)
    field(:color, :string)
    field(:prefix, :string)
    belongs_to(:layout, WraftDoc.Document.Layout)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:flow, WraftDoc.Enterprise.Flow)

    has_many(:instances, WraftDoc.Document.Instance)
    has_many(:fields, WraftDoc.Document.ContentTypeField)

    timestamps()
  end

  def changeset(%ContentType{} = content_type, attrs \\ %{}) do
    content_type
    |> cast(attrs, [:name, :description, :color, :prefix, :organisation_id])
    |> validate_required([:name, :description, :prefix, :organisation_id])
    |> unique_constraint(:name,
      message: "Content type with the same name under your organisation exists.!",
      name: :content_type_organisation_unique_index
    )
    |> validate_format(:color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
  end

  def update_changeset(%ContentType{} = content_type, attrs \\ %{}) do
    content_type
    |> cast(attrs, [:name, :description, :color, :layout_id, :flow_id, :prefix])
    |> validate_required([:name, :description, :layout_id, :flow_id, :prefix])
    |> unique_constraint(:name,
      message: "Content type with the same name under your organisation exists.!",
      name: :content_type_organisation_unique_index
    )
    |> validate_length(:prefix, min: 2, max: 6)
    |> validate_format(:color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
  end
end
