defmodule WraftDoc.Document.Theme do
  @moduledoc """
  The theme model.
  ### Fields
  * `name` - The name of the theme, `:string`
  * `font` - The font name. `:string`
  * `typescale` - The type scale to use, example: `{ "p": 6, "h2": 8, "h1": 10}`.
  * `body_color` - The Body color of the theme, hex-code must be in the format of `#RRGGBB`.
  * `primary_color` - The Primary color of the theme, hex-code must be in the format of `#RRGGBB`.
  * `secondary_color` - The Secondary color of the theme, hex-code must be in the format of `#RRGGBB`.
  * `defualt_theme` - Defualt Theme to use, `true` or `false`
  * `preview_file` - The Preview file to use. currently supporting formats are `.png` `.jpeg` `.pdf` `.jpg` `.gif`.
  * `file` - The font file to use. currently supporting formats are `.ttf` `.otf` `.pdf`.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema
  alias __MODULE__
  alias WraftDoc.Account.User

  @hex_code_warning_msg "hex-code must be in the format of `#RRGGBB`"
  @derive {Jason.Encoder, only: [:name]}

  defimpl Spur.Trackable, for: Theme do
    def actor(theme), do: "#{theme.creator_id}"
    def object(theme), do: "Theme:#{theme.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  @fields [
    :name,
    :font,
    :typescale,
    :organisation_id,
    :body_color,
    :primary_color,
    :secondary_color,
    :default_theme
  ]

  schema "theme" do
    field(:name, :string, null: false)
    field(:font, :string)
    field(:typescale, :map, default: %{})
    field(:body_color, :string)
    field(:primary_color, :string)
    field(:secondary_color, :string)
    field(:default_theme, :boolean, default: false)
    field(:preview_file, WraftDocWeb.ThemePreviewUploader.Type)
    field(:file, WraftDocWeb.ThemeUploader.Type)

    belongs_to(:creator, User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:content_type, WraftDoc.Document.ContentType)

    timestamps()
  end

  @hex_format ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/

  def changeset(%Theme{} = theme, attrs \\ %{}) do
    theme
    |> cast(attrs, @fields)
    |> validate_required([:name, :font, :typescale, :organisation_id])
    |> validate_format(:body_color, @hex_format, message: @hex_code_warning_msg)
    |> validate_format(:primary_color, @hex_format, message: @hex_code_warning_msg)
    |> validate_format(:secondary_color, @hex_format, message: @hex_code_warning_msg)
  end

  def file_changeset(%Theme{} = theme, attrs \\ %{}) do
    theme
    |> cast_attachments(attrs, [:file, :preview_file])
    |> validate_required([:file])
  end

  def update_changeset(%Theme{} = theme, attrs \\ %{}) do
    theme
    |> cast(attrs, @fields)
    |> cast_attachments(attrs, [:file, :preview_file])
    |> validate_required([:name, :font, :typescale, :file])
    |> validate_format(:body_color, @hex_format, message: @hex_code_warning_msg)
    |> validate_format(:primary_color, @hex_format, message: @hex_code_warning_msg)
    |> validate_format(:secondary_color, @hex_format, message: @hex_code_warning_msg)
  end
end
