defmodule WraftDoc.Document.Pipeline do
  @moduledoc """
  The pipeline model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  @derive {Jason.Encoder, only: [:id, :name, :api_route]}
  schema "pipeline" do
    field(:name, :string)
    field(:api_route, :string)
    field(:source, :string)
    field(:source_id, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:stages, WraftDoc.Document.Pipeline.Stage)
    has_many(:trigger_histories, WraftDoc.Document.Pipeline.TriggerHistory)
    has_many(:form_pipelines, WraftDoc.Forms.FormPipeline)
    has_many(:forms, through: [:form_pipelines, :form])
    timestamps()
  end

  def changeset(%Pipeline{} = pipeline, attrs \\ %{}) do
    pipeline
    |> cast(attrs, [:name, :api_route, :organisation_id, :source, :source_id])
    |> validate_required([:name, :api_route, :organisation_id])
    |> enforce_name_upper_case()
    |> unique_constraint(:name,
      message: "Pipeline with the same name already exists.!",
      name: "organisation_pipeline_unique_index"
    )
  end

  def update_changeset(%Pipeline{} = pipeline, attrs \\ %{}) do
    pipeline
    |> cast(attrs, [:name, :api_route, :source, :source_id])
    |> validate_required([:name, :api_route])
    |> enforce_name_upper_case()
    |> unique_constraint(:name,
      message: "Pipeline with the same name already exists.!",
      name: "organisation_pipeline_unique_index"
    )
  end

  defp enforce_name_upper_case(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        put_change(changeset, :name, String.upcase(name))
    end
  end
end
