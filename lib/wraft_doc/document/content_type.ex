defmodule WraftDoc.Document.ContentType do
  @moduledoc """
    The content type model.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.Document.ContentType
  alias WraftDoc.Document.Layout
  alias WraftDoc.Document.Theme
  alias WraftDoc.Enterprise.Flow

  @derive {Jason.Encoder, only: [:id]}

  schema "content_type" do
    field(:name, :string)
    field(:description, :string)
    field(:color, :string)
    field(:prefix, :string)
    belongs_to(:layout, Layout)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:flow, Flow)
    belongs_to(:theme, Theme)

    has_many(:instances, WraftDoc.Document.Instance)
    has_many(:content_type_fields, WraftDoc.Document.ContentTypeField)
    has_many(:fields, through: [:content_type_fields, :field])
    has_many(:stages, WraftDoc.Document.Pipeline.Stage)
    has_many(:pipelines, through: [:stages, :pipeline])
    has_many(:content_type_roles, WraftDoc.Document.ContentTypeRole)
    has_many(:roles, through: [:content_type_roles, :role])

    timestamps()
  end

  def changeset(%ContentType{} = content_type, attrs \\ %{}) do
    content_type
    |> cast(
      attrs,
      [
        :name,
        :description,
        :prefix,
        :color,
        :layout_id,
        :flow_id,
        :theme_id,
        :organisation_id,
        :creator_id
      ]
    )
    |> validate_required([
      :name,
      :prefix,
      :layout_id,
      :flow_id,
      :theme_id,
      :organisation_id,
      :creator_id
    ])
    |> unique_constraint(
      :name,
      message: "Content type with the same name under your organisation exists.!",
      name: :content_type_organisation_unique_index
    )
    |> validate_length(:prefix, min: 2, max: 6)
    |> validate_format(:color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
  end

  def update_changeset(%ContentType{} = content_type, attrs \\ %{}) do
    content_type
    |> cast(attrs, [:name, :description, :color, :layout_id, :flow_id, :prefix, :theme_id])
    |> validate_required([:name, :description, :layout_id, :flow_id, :prefix, :theme_id])
    |> unique_constraint(
      :name,
      message: "Content type with the same name under your organisation exists.!",
      name: :content_type_organisation_unique_index
    )
    |> organisation_constraint(Layout, :layout_id)
    |> organisation_constraint(Flow, :flow_id)
    |> organisation_constraint(Theme, :theme_id)
    |> validate_length(:prefix, min: 2, max: 6)
    |> validate_format(:color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
  end
end
