defmodule WraftDoc.Frames.FrameAsset do
  @moduledoc false
  use Waffle.Ecto.Schema
  use WraftDoc.Schema

  alias WraftDoc.Assets.Asset
  alias WraftDoc.Frames.Frame

  schema "frame_asset" do
    belongs_to(:frame, Frame)
    belongs_to(:asset, Asset)

    timestamps()
  end

  def changeset(frame_asset, attrs \\ %{}) do
    frame_asset
    |> cast(attrs, [:frame_id, :asset_id])
    |> validate_required([:frame_id, :asset_id])
  end
end
