defmodule WraftDoc.Document.Pipeline.Stage do
  @moduledoc """
  The pipeline stages model.
  """
  alias __MODULE__
  alias WraftDoc.Account.User
  use WraftDoc.Schema

  defimpl Spur.Trackable, for: Stage do
    def actor(stage), do: "#{stage.creator_id}"
    def object(stage), do: "Stage:#{stage.id}"
    def target(_chore), do: nil

    def audience(%{creator_id: id}) do
      from(u in User, where: u.id == ^id)
    end
  end

  schema "pipe_stage" do
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:pipeline, WraftDoc.Document.Pipeline)
    belongs_to(:data_template, WraftDoc.Document.DataTemplate)
    belongs_to(:state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:creator, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%Stage{} = stage, attrs \\ %{}) do
    stage
    |> cast(attrs, [])
    |> validate_required([
      :content_type_id,
      :pipeline_id,
      :data_template_id,
      :state_id,
      :creator_id
    ])
    |> unique_constraint(:content_type_id,
      name: :pipe_stages_unique_index,
      message: "Already added.!"
    )
  end

  def update_changeset(%Stage{} = stage, attrs \\ %{}) do
    stage
    |> cast(attrs, [:content_type_id, :data_template_id, :state_id])
    |> validate_required([
      :content_type_id,
      :data_template_id,
      :state_id
    ])
    |> unique_constraint(:content_type_id,
      name: :pipe_stages_unique_index,
      message: "Already added.!"
    )
  end
end
