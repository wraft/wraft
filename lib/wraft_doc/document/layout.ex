defmodule WraftDoc.Document.Layout do
  @moduledoc """
  The layout model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema
  alias __MODULE__

  schema "layout" do
    field(:name, :string)
    field(:description, :string)
    field(:width, :float)
    field(:height, :float)
    field(:unit, :string)
    field(:slug, :string)
    field(:screenshot, WraftDocWeb.LayoutScreenShotUploader.Type)

    belongs_to(:engine, WraftDoc.Document.Engine)
    belongs_to(:frame, WraftDoc.Document.Frame)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:content_types, WraftDoc.Document.ContentType)
    has_many(:layout_assets, WraftDoc.Document.LayoutAsset)
    has_many(:assets, through: [:layout_assets, :asset])

    timestamps()
  end

  def changeset(%Layout{} = layout, attrs \\ %{}) do
    layout
    |> cast(attrs, [
      :name,
      :description,
      :width,
      :height,
      :unit,
      :slug,
      :organisation_id,
      :engine_id
    ])
    |> validate_required([
      :name,
      :description,
      :slug,
      :organisation_id,
      :engine_id
    ])
    |> unique_constraint(:name,
      message: "Layout with the same name exists. Use another name.!",
      name: :layout_organisation_unique_index
    )
  end

  def update_changeset(%Layout{} = layout, attrs \\ %{}) do
    layout
    |> cast(attrs, [
      :name,
      :description,
      :width,
      :height,
      :unit,
      :slug,
      :engine_id
    ])
    |> cast_attachments(attrs, [:screenshot])
    |> validate_required([
      :name,
      :description,
      :slug,
      :engine_id
    ])
    |> unique_constraint(:name,
      message: "Layout with the same name exists. Use another name.!",
      name: :layout_organisation_unique_index
    )
  end

  def file_changeset(%Layout{} = layout, attrs \\ %{}) do
    cast_attachments(layout, attrs, [:screenshot])
  end
end
