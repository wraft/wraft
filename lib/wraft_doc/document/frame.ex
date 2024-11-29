defmodule WraftDoc.Document.Frame do
  @moduledoc false
  use Waffle.Ecto.Schema
  use WraftDoc.Schema

  schema "frame" do
    field(:name, :string)
    field(:frame_file, WraftDocWeb.FrameUploader.Type)

    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(frame, attrs) do
    frame
    |> cast(attrs, [:name, :organisation_id, :creator_id])
    |> validate_required([:name, :organisation_id, :creator_id])
  end

  def file_changeset(frame, attrs) do
    frame
    |> cast_attachments(attrs, [:frame_file])
    |> validate_required([:frame_file])
  end

  def update_changeset(frame, attrs) do
    frame
    |> cast(attrs, [:name, :organisation_id, :creator_id])
    |> cast_attachments(attrs, [:frame_file])
    |> validate_required([:name, :frame_file])
  end
end
