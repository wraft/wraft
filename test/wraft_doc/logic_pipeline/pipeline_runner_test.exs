defmodule WraftDoc.PipelineRunnerTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  use ExUnit.Case
  alias WraftDoc.PipelineRunner

  describe "preload_pipeline_and_stages/1" do
    test "returns preloaded trigger struct with trigger struct as input" do
      pipeline = insert(:pipeline)
      c_type = insert(:content_type)
      stage = insert(:pipe_stage, pipeline: pipeline, content_type: c_type)
      c_type_field = insert(:content_type_field, content_type: c_type)
      trigger = insert(:trigger_history, pipeline: pipeline)

      preloaded_trigger = PipelineRunner.preload_pipeline_and_stages(trigger)

      preloaded_content_type_field_names =
        preloaded_trigger.pipeline.stages
        |> Enum.map(fn stage ->
          stage.content_type.fields |> Enum.map(fn field -> field.name end)
        end)
        |> List.flatten()
        |> List.to_string()

      assert preloaded_trigger.id == trigger.id
      assert preloaded_trigger.pipeline.name == trigger.pipeline.name
      assert preloaded_content_type_field_names =~ c_type_field.name
    end

    test "returns nil with wrong data" do
      response = PipelineRunner.preload_pipeline_and_stages(nil)
      assert response == nil
    end
  end

  describe "pipeline_exists?/1" do
    test "returns true with valid input" do
      pipeline = insert(:pipeline)
      response = PipelineRunner.pipeline_exists?(%{pipeline: pipeline})
      assert response == true
    end

    test "returns true with invalid input" do
      response = PipelineRunner.pipeline_exists?(%{pipeline: nil})
      assert response == false
    end
  end
end
