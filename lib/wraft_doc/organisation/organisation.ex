defmodule WraftDoc.Enterprise.Organisation do
  @moduledoc """
    The organisation model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Enterprise.Organisation

  schema "organisation" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    timestamps()
  end

  def changeset(%Organisation{} = organisation, attrs \\ %{}) do
    organisation
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name,
      message: "Organisation name already taken.! Try another one.",
      name: :organisation_unique_index
    )
  end
end
