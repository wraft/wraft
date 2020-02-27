defmodule WraftDoc.Document.Theme do
  @moduledoc """
    The theme model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.Theme

  schema "theme" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:font, :string)
    field(:typescale, {:array, :string}, default: %{})
    field(:file, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%Theme{} = theme, attrs \\ %{}) do
    theme
    |> cast(attrs, [:name, :font, :typescale, :file, :organisation_id])
    |> validate_required([:name, :font, :typescale, :file, :organisation_id])
  end
end
