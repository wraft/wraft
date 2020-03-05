defmodule WraftDoc.Document.Theme do
  @moduledoc """
    The theme model.
  """
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.Theme

  schema "theme" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:font, :string)
    field(:typescale, :map, default: %{})
    field(:file, WraftDocWeb.ThemeUploader.Type)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
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
