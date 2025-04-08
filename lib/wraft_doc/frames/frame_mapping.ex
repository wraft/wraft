defmodule WraftDoc.Frames.FrameMapping do
  @moduledoc """
  Frame mapping for a frame.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Frames.Frame

  @form_mapping_fields [:frame_id, :content_type_id]
  @mapping_fields [:source, :destination]

  schema "frame_mapping" do
    embeds_many :mapping, Mapping, primary_key: false, on_replace: :delete do
      field(:source, :map)
      field(:destination, :map)
    end

    belongs_to(:frame, Frame)
    belongs_to(:content_type, ContentType)

    timestamps()
  end

  def changeset(frame_mapping, attrs) do
    frame_mapping
    |> cast(attrs, @form_mapping_fields)
    |> cast_embed(:mapping, required: true, with: &map_changeset/2)
    |> validate_required(@form_mapping_fields)
    |> foreign_key_constraint(:frame_id, message: "Please enter an existing frame")
    |> foreign_key_constraint(:content_type_id, message: "Please enter an existing content type")
    |> unique_constraint(@form_mapping_fields,
      name: :frame_content_type_unique_index,
      message: "already exist"
    )
  end

  def update_changeset(frame_mapping, attrs) do
    frame_mapping
    |> cast(attrs, @form_mapping_fields)
    |> cast_embed(:mapping, required: true, with: &map_changeset/2)
    |> validate_required(@form_mapping_fields)
    |> foreign_key_constraint(:frame_id, message: "Please enter an existing frame")
    |> foreign_key_constraint(:content_type_id, message: "Please enter an existing content type")
    |> unique_constraint(@form_mapping_fields,
      name: :frame_content_type_unique_index,
      message: "already exist"
    )
  end

  def map_changeset(%FrameMapping.Mapping{} = mapping, attrs \\ %{}) do
    mapping
    |> cast(attrs, @mapping_fields)
    |> validate_required(@mapping_fields)
  end
end
