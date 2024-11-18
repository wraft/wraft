defmodule WraftDoc.Document.DataTemplate do
  @moduledoc false
  use WraftDoc.Schema
  use EctoTypesense.Schema

  alias __MODULE__

  schema "data_template" do
    field(:title, :string)
    field(:title_template, :string)
    field(:data, :string)
    field(:serialized, :map, default: %{})
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%DataTemplate{} = d_template, attrs \\ %{}) do
    d_template
    |> cast(attrs, [:title, :title_template, :data, :serialized, :content_type_id, :creator_id])
    |> validate_required([:title, :title_template, :data, :content_type_id])
  end
end
