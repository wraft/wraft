defmodule WraftDoc.Document.Pipeline.Stage do
  @moduledoc """
  The pipeline stages model.
  """
  alias __MODULE__
  use Ecto.Schema
  import Ecto.Changeset

  schema "pipe_stage" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:pipeline, WraftDoc.Document.Pipeline)
  end

  def changeset(%Stage{} = stage, attrs \\ %{}) do
    stage
    |> cast(attrs, [])
    |> unique_constraint(:content_type_id,
      name: :pipe_stages_unique_index,
      message: "Already added.!"
    )
  end
end
