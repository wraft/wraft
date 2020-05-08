defmodule WraftDoc.Document.Pipeline.Stage do
  @moduledoc """
  The pipeline stages model.
  """
  alias __MODULE__
  alias WraftDoc.{Account.User, Document.Pipeline}
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  defimpl Spur.Trackable, for: Stage do
    def actor(_stage), do: ""
    def object(stage), do: "Stage:#{stage.id}"
    def target(_chore), do: nil

    def audience(%{pipeline_id: id}) do
      from(u in User,
        join: p in Pipeline,
        where: p.id == ^id,
        where: u.organisation_id == p.organisation_id
      )
    end
  end

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
