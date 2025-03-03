defmodule WraftDoc.DataTemplates.DataTemplate do
  @moduledoc false
  use WraftDoc.Schema
  @behaviour ExTypesense

  alias __MODULE__

  schema "data_template" do
    field(:title, :string)
    field(:title_template, :string)
    field(:data, :string)
    field(:serialized, :map, default: %{})
    belongs_to(:content_type, WraftDoc.ContentTypes.ContentType)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%DataTemplate{} = d_template, attrs \\ %{}) do
    d_template
    |> cast(attrs, [:title, :title_template, :data, :serialized, :content_type_id, :creator_id])
    |> validate_required([:title, :title_template, :data, :content_type_id])
  end

  @impl ExTypesense

  def get_field_types do
    %{
      fields: [
        %{name: "id", type: "string", facet: false},
        %{name: "name", type: "string", facet: true},
        %{name: "title_template", type: "string", facet: true},
        %{name: "data", type: "string", facet: true},
        %{name: "serialized", type: "string", facet: false},
        %{name: "content_type_id", type: "string", facet: true},
        %{name: "creator_id", type: "string", facet: true},
        %{name: "inserted_at", type: "int64", facet: false},
        %{name: "updated_at", type: "int64", facet: false},
        %{name: "organisation_id", type: "string", facet: true}
      ]
    }
  end
end
