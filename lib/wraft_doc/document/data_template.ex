defmodule WraftDoc.Document.DataTemplate do
  @moduledoc false
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.{Account.User, Document.ContentType}
  import Ecto.Query
  @derive {Jason.Encoder, only: [:title]}
  defimpl Spur.Trackable, for: DataTemplate do
    def actor(data_template), do: "#{data_template.creator_id}"
    def object(data_template), do: "DataTemplate:#{data_template.id}"
    def target(_chore), do: nil

    def audience(%{content_type_id: id}) do
      from(u in User,
        join: ct in ContentType,
        where: ct.id == ^id,
        where: u.organisation_id == ct.organisation_id
      )
    end
  end

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
    |> cast(attrs, [:title, :title_template, :data, :serialized])
    |> validate_required([:title, :title_template, :data])
  end
end
