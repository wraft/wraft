defmodule WraftDoc.Document.Layout do
  @moduledoc """
  The layout model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  import Ecto.Query
  alias __MODULE__
  alias WraftDoc.Account.User
  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: Layout do
    def actor(layout), do: "#{layout.creator_id}"
    def object(layout), do: "Layout:#{layout.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "layout" do
    field(:name, :string, null: false)
    field(:description, :string)
    field(:width, :float)
    field(:height, :float)
    field(:unit, :string)
    field(:slug, :string)
    field(:slug_file, WraftDocWeb.LayoutSlugUploader.Type)
    field(:screenshot, WraftDocWeb.LayoutScreenShotUploader.Type)
    belongs_to(:engine, WraftDoc.Document.Engine)
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
      :width,
      :height,
      :unit,
      :slug,
      :organisation_id,
      :engine_id
    ])
    |> unique_constraint(:name,
      message: "Layout with the same name exists. Use another name.!",
      name: :layout_name_unique_index
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
    |> cast_attachments(attrs, [:slug_file, :screenshot])
    |> validate_required([
      :name,
      :description,
      :width,
      :height,
      :unit,
      :slug,
      :engine_id
    ])
    |> unique_constraint(:name,
      message: "Layout with the same name exists. Use another name.!",
      name: :layout_name_unique_index
    )
  end

  def file_changeset(%Layout{} = layout, attrs \\ %{}) do
    cast_attachments(layout, attrs, [:slug_file, :screenshot])
  end
end
