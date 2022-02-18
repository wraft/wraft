defmodule WraftDoc.Document.Theme do
  @moduledoc """
    The theme model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema
  alias __MODULE__
  alias WraftDoc.Account.User
  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: Theme do
    def actor(theme), do: "#{theme.creator_id}"
    def object(theme), do: "Theme:#{theme.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "theme" do
    field(:name, :string, null: false)
    field(:font, :string)
    field(:typescale, :map, default: %{})
    field(:file, WraftDocWeb.ThemeUploader.Type)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:content_type, WraftDoc.Document.ContentType)

    timestamps()
  end

  def changeset(%Theme{} = theme, attrs \\ %{}) do
    theme
    |> cast(attrs, [:name, :font, :typescale, :organisation_id])
    |> validate_required([:name, :font, :typescale, :organisation_id])
  end

  def file_changeset(%Theme{} = theme, attrs \\ %{}) do
    theme
    |> cast_attachments(attrs, [:file])
    |> validate_required([:file])
  end

  def update_changeset(%Theme{} = theme, attrs \\ %{}) do
    theme
    |> cast(attrs, [:name, :font, :typescale])
    |> cast_attachments(attrs, [:file])
    |> validate_required([:name, :font, :typescale, :file])
  end
end
