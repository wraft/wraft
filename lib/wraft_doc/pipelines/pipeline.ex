defmodule WraftDoc.Pipelines.Pipeline do
  @moduledoc """
  The pipeline model.
  """
  use WraftDoc.Schema
  @behaviour ExTypesense

  alias __MODULE__

  @derive {Jason.Encoder, only: [:id, :name, :api_route]}
  schema "pipeline" do
    field(:name, :string)
    field(:api_route, :string)
    field(:source, :string)
    field(:source_id, :string)
    field(:stages_count, :integer, virtual: true)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:stages, WraftDoc.Pipelines.Stages.Stage)
    has_many(:trigger_histories, WraftDoc.Pipelines.TriggerHistories.TriggerHistory)
    has_many(:form_pipelines, WraftDoc.Forms.FormPipeline)
    has_many(:forms, through: [:form_pipelines, :form])
    timestamps()
  end

  def changeset(%Pipeline{} = pipeline, attrs \\ %{}) do
    pipeline
    |> cast(attrs, [:name, :api_route, :organisation_id, :source, :source_id])
    |> validate_required([:name, :api_route, :organisation_id])
    |> unique_constraint(:name,
      message: "Pipeline with the same name already exists.!",
      name: "organisation_pipeline_unique_index"
    )
  end

  def update_changeset(%Pipeline{} = pipeline, attrs \\ %{}) do
    pipeline
    |> cast(attrs, [:name, :api_route, :source, :source_id])
    |> validate_required([:name, :api_route])
    |> unique_constraint(:name,
      message: "Pipeline with the same name already exists.!",
      name: "organisation_pipeline_unique_index"
    )
  end

  @impl ExTypesense
  def get_field_types do
    %{
      fields: [
        %{name: "id", type: "string", facet: false},
        %{name: "name", type: "string", facet: true},
        %{name: "api_route", type: "string", facet: true},
        %{name: "source", type: "string", facet: true},
        %{name: "source_id", type: "string", facet: true},
        %{name: "stages_count", type: "int32", facet: true},
        %{name: "creator_id", type: "string", facet: true},
        %{name: "organisation_id", type: "string", facet: true},
        %{name: "inserted_at", type: "int64", facet: false},
        %{name: "updated_at", type: "int64", facet: false}
      ]
    }
  end
end
