defmodule WraftDoc.Document.Block do
  @moduledoc """
    The block model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias WraftDoc.Account.User
  import Ecto.Query

  defimpl Spur.Trackable, for: Block do
    def actor(block), do: "#{block.creator_id}"
    def object(block), do: "Block:#{block.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "block" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:btype, :string)
    field(:dataset, :map)
    field(:file_url, :string)
    field(:api_route, :string)
    field(:endpoint, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%Block{} = block, attrs \\ %{}) do
    block
    |> cast(attrs, [
      :name,
      :btype,
      :dataset,
      :file_url,
      :api_route,
      :endpoint,
      :creator_id,
      :organisation_id
    ])
    |> validate_required([:name, :file_url, :creator_id, :dataset, :organisation_id])
    |> unique_constraint(:name,
      message: "Block with same name exists.!",
      name: :block_content_type_unique_index
    )
  end
end
