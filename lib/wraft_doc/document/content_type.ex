defmodule WraftDoc.Document.ContentType do
  @moduledoc """
    The content type model.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.Account.User
  alias WraftDoc.Document.ContentType
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

    has_many(:stages, WraftDoc.Document.Pipeline.Stage)
    has_many(:pipelines, through: [:stages, :pipeline])
    has_many(:content_type_roles, WraftDoc.Document.ContentTypeRole)
    has_many(:roles, through: [:content_type_roles, :role])

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
    |> unique_constraint(:name,
      message: "Content type with the same name under your organisation exists.!",
      name: :content_type_organisation_unique_index
    )
    |> validate_length(:prefix, min: 2, max: 6)
    |> validate_format(:color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
  end

  defimpl Poison.Encoder, for: WraftDoc.Document.ContentType do
    def encode(%{__struct__: _} = struct, options) do
      map =
        struct
        |> Map.from_struct()
        |> Map.drop([:__meta__, :__struct__])

      Poison.Encoder.Map.encode(map, options)
    end
  end
end
