defmodule WraftDoc.Frames.FrameField do
  @moduledoc """
  The form field schema.
  """
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.Fields.Field
  alias WraftDoc.Frames.Frame

  @fields [:frame_id, :field_id]

  schema "frame_field" do
    belongs_to(:frame, Frame)
    belongs_to(:field, Field)

    timestamps()
  end

  def changeset(%FrameField{} = fame_field, attrs \\ %{}) do
    fame_field
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> foreign_key_constraint(:frame_id, message: "Please enter an existing content type")
    |> foreign_key_constraint(:field_id, message: "Please enter a valid field")
  end
end
