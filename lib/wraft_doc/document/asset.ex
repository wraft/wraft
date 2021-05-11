defmodule WraftDoc.Document.Asset do
  @moduledoc """
    The asset model.
  """
  alias __MODULE__
  alias WraftDoc.Account.User
  use WraftDoc.Schema
  use Arc.Ecto.Schema

  import Ecto.Query
  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: Asset do
    def actor(asset), do: "#{asset.creator_id}"
    def object(asset), do: "Asset:#{asset.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "asset" do
    field(:name, :string, null: false)
    field(:file, WraftDocWeb.AssetUploader.Type)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:name, :organisation_id])
    |> validate_required([:name, :organisation_id])
  end

  def update_changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:name])
    |> cast_attachments(attrs, [:file])
    |> validate_required([:name, :file])
  end

  def file_changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast_attachments(attrs, [:file])
    |> validate_required([:file])
  end
end
