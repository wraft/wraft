defmodule WraftDoc.Repo.Migrations.LinkFormAndPipelineIfItDoesntExist do
  @moduledoc """
  Script for linking form and pipeline if it doesn't exist

  mix run priv/repo/data/migrations/link_form_and_pipeline_if_it_doesnt_exist.exs
  """
  require Logger
  import Ecto.Query, warn: false
  alias WraftDoc.Document.Pipeline
  alias WraftDoc.Forms.FormPipeline
  alias WraftDoc.Repo

  Logger.info("Starting linking form and pipeline if it doesn't exist")

  Pipeline
  |> Repo.all()
  |> Enum.each(fn pipeline ->
    try do
      Repo.insert!(%FormPipeline{form_id: pipeline.source_id, pipeline_id: pipeline.id})
    rescue
      e in Ecto.ConstraintError ->
        Logger.info("FormPipeline already exists for pipeline #{pipeline.id}")
    end
  end)

  Logger.info("Linking form and pipeline completed")
end
