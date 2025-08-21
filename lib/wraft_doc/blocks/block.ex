defmodule WraftDoc.Blocks.Block do
  @moduledoc """
    The block model.
  """
  use WraftDoc.Schema
  @behaviour ExTypesense

  use Waffle.Ecto.Schema
  alias __MODULE__

  schema "block" do
    field(:name, :string)
    field(:description, :string)
    field(:btype, :string)
    field(:dataset, :map)
    field(:input, WraftDocWeb.BlockInputUploader.Type)
    field(:file_url, :string)
    field(:api_route, :string)
    field(:endpoint, :string)
    field(:tex_chart, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%Block{} = block, %{"input" => _} = attrs) do
    block
    |> cast(attrs, [
      :name,
      :btype,
      :file_url,
      :api_route,
      :endpoint,
      :creator_id,
      :organisation_id
    ])
    |> validate_required([:name, :file_url, :creator_id, :organisation_id])
    |> unique_constraint(:name,
      message: "Block with same name exists.!",
      name: :block_organisation_unique_index
    )
  end

  def changeset(%Block{} = block, attrs) do
    block
    |> cast(attrs, [
      :name,
      :btype,
      :dataset,
      :file_url,
      :api_route,
      :endpoint,
      :tex_chart,
      :creator_id,
      :organisation_id
    ])
    |> validate_required([:name, :file_url, :creator_id, :dataset, :organisation_id])
    |> unique_constraint(:name,
      message: "Block with same name exists.!",
      name: :block_organisation_unique_index
    )
  end

  def block_input_changeset(%Block{} = block, attrs) do
    cast_attachments(block, attrs, [:input])
  end

  @impl ExTypesense
  def get_field_types do
    %{
      fields: [
        %{name: "internal_id", type: "string", facet: false},
        %{name: "name", type: "string", facet: true},
        %{name: "description", type: "string", facet: false},
        %{name: "btype", type: "string", facet: true},
        %{name: "dataset", type: "string", facet: false},
        %{name: "input", type: "string", facet: false},
        %{name: "file_url", type: "string", facet: false},
        %{name: "api_route", type: "string", facet: true},
        %{name: "endpoint", type: "string", facet: true},
        %{name: "tex_chart", type: "string", facet: false},
        %{name: "creator_id", type: "string", facet: true},
        %{name: "organisation_id", type: "string", facet: true},
        %{name: "inserted_at", type: "int64", facet: false},
        %{name: "updated_at", type: "int64", facet: false}
      ]
    }
  end
end
