defmodule WraftDoc.Document.DocumentAsset do
  @moduledoc """
    The Document-asset association model.
  """
  use WraftDoc.Schema
  alias __MODULE__

  schema "document_assets" do
    belongs_to(:asset, WraftDoc.Document.Asset)
    belongs_to(:document, WraftDoc.Document.Instance)

    timestamps()
  end

  def changeset(%DocumentAsset{} = document_asset, attrs \\ %{}) do
    document_asset
    |> cast(attrs, [:asset_id, :document_id])
    |> validate_required([:asset_id, :document_id])
  end
end
