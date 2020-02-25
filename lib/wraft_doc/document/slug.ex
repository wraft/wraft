defmodule WraftDoc.Document.Slug do
  @moduledoc """
    The slug model.
  """
  alias WraftDoc.Document.Slug
  use Ecto.Schema
  import Ecto.Changeset

  schema "slug" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%Slug{} = slug, attrs \\ %{}) do
    slug
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name,
      message: "Slug with the same name exists. Use another name.!",
      name: :slug_name_unique_index
    )
  end
end
