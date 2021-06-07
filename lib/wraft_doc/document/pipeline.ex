defmodule WraftDoc.Document.Pipeline do
  @moduledoc """
  The pipeline model.
  """
  alias __MODULE__
  alias WraftDoc.Account.User
  use WraftDoc.Schema

  defimpl Spur.Trackable, for: Pipeline do
    def actor(pipeline), do: "#{pipeline.creator_id}"
    def object(pipeline), do: "Pipeline:#{pipeline.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  @derive {Jason.Encoder, only: [:id, :name, :api_route]}
  schema "pipeline" do
    field(:name, :string)
    field(:api_route, :string)
    belongs_to(:creator, User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:stages, WraftDoc.Document.Pipeline.Stage)
    has_many(:trigger_histories, WraftDoc.Document.Pipeline.TriggerHistory)
    timestamps()
  end

  def changeset(%Pipeline{} = pipeline, attrs \\ %{}) do
    pipeline
    |> cast(attrs, [:name, :api_route, :organisation_id])
    |> validate_required([:name, :api_route, :organisation_id])
    |> unique_constraint(:name,
      message: "Pipeline with the same name already exists.!",
      name: "organisation_pipeline_unique_index"
    )
  end

  def update_changeset(%Pipeline{} = pipeline, attrs \\ %{}) do
    pipeline
    |> cast(attrs, [:name, :api_route])
    |> validate_required([:name, :api_route])
    |> unique_constraint(:name,
      message: "Pipeline with the same name already exists.!",
      name: "organisation_pipeline_unique_index"
    )
  end
end
