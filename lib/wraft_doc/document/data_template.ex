defmodule WraftDoc.Document.DataTemplate do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "data_template" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:title, :string)
    field(:title_template, :string)
    field(:data, :string)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%DataTemplate{} = d_template, attrs \\ %{}) do
    d_template
    |> cast(attrs, [:title, :title_template, :data])
    |> validate_required([:title, :title_template, :data])
  end
end
