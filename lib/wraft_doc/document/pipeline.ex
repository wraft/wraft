defmodule WraftDoc.Document.Pipeline do
  @moduledoc """
  The pipeline model.
  """
  alias __MODULE__
  alias WraftDoc.Account.User
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  defimpl Spur.Trackable, for: Pipeline do
    def actor(pipeline), do: "#{pipeline.creator_id}"
    def object(pipeline), do: "Pipeline:#{pipeline.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  @derive {Jason.Encoder, only: [:name, :api_route]}
  schema "pipeline" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:name, :string)
    field(:api_route, :string)
    belongs_to(:creator, User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:stages, WraftDoc.Document.Pipeline.Stage)
    has_many(:content_types, through: [:stages, :content_type])

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
end
