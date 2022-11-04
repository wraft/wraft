defmodule WraftDoc.Document.Block do
  @moduledoc """
    The block model.
  """
  use WraftDoc.Schema

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
    |> cast_attachments(attrs, [:input])
    |> validate_required([:name, :file_url, :creator_id, :input, :organisation_id])
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
end
