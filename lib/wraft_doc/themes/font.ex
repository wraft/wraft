defmodule WraftDoc.Themes.Font do
  @moduledoc """
  The font model.
  ### Fields
  * `name` - The name of the font, `:string`
  * `file` - The font file to use. currently supporting formats are `.ttf` `.otf`.
  * `organisation_id` - The organisation this font belongs to
  """

  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  alias __MODULE__
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Themes.FontAsset

  @fields [
    :name,
    :organisation_id,
    :creator_id
  ]

  schema "fonts" do
    field(:name, :string)

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)

    many_to_many(:assets, Asset, join_through: FontAsset)

    timestamps()
  end

  def changeset(%Font{} = font, attrs \\ %{}) do
    font
    |> cast(attrs, @fields)
    |> validate_required([:name, :organisation_id])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:name, :organisation_id],
      name: :font_name_organisation_id_index,
      message: "Font name must be unique within the organisation"
    )
  end

  def file_changeset(%Font{} = font, attrs \\ %{}) do
    cast_attachments(font, attrs, [:file])
  end

  def update_changeset(%Font{} = font, attrs \\ %{}) do
    font
    |> cast(attrs, @fields)
    |> cast_attachments(attrs, [:file])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:name, :organisation_id],
      name: :font_name_organisation_id_index,
      message: "Font name must be unique within the organisation"
    )
  end
end
