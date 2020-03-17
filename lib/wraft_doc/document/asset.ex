defmodule WraftDoc.Document.Asset do
  @moduledoc """
    The asset model.
  """
  alias __MODULE__
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  schema "asset" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
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
