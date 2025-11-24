defmodule WraftDoc.PipelineRunnerTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  use ExUnit.Case
  alias WraftDoc.{Documents.Instance, PipelineRunner}

  describe "preload_pipeline_and_stages/1" do
    test "returns preloaded trigger struct with trigger struct as input" do
      pipeline = insert(:pipeline)
      content_type = insert(:content_type)
      insert(:pipe_stage, pipeline: pipeline, content_type: content_type)
      content_type_field = insert(:content_type_field, content_type: content_type)
      trigger = insert(:trigger_history, pipeline: pipeline)

      preloaded_trigger = PipelineRunner.preload_pipeline_and_stages(trigger)

      field_names =
        preloaded_trigger.pipeline.stages
        |> Enum.map(fn stage ->
          Enum.map(stage.content_type.fields, fn field -> field.name end)
        end)
        |> List.flatten()
        |> List.to_string()

      assert preloaded_trigger.id == trigger.id
      assert preloaded_trigger.pipeline.name == trigger.pipeline.name
      assert field_names =~ content_type_field.field.name
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

  describe "create_instances/1" do
    test "creates instance and returns a map with created instance when trigger has a creator_id" do
      pipeline = insert(:pipeline)
      flow = insert(:flow)
      insert(:state, flow: flow, order: 1)
      insert(:state, flow: flow, order: 2)
      c_type1 = insert(:content_type, flow: flow)
      c_type2 = insert(:content_type, flow: flow)
      pipe_stage1 = insert(:pipe_stage, pipeline: pipeline, content_type: c_type1)
      pipe_stage2 = insert(:pipe_stage, pipeline: pipeline, content_type: c_type2)
      content_type_field_1 = insert(:content_type_field, content_type: c_type1)
      content_type_field_2 = insert(:content_type_field, content_type: c_type2)

      insert(:form_mapping, pipe_stage: pipe_stage1)
      insert(:form_mapping, pipe_stage: pipe_stage2)

      pipeline =
        Repo.preload(pipeline,
          stages: [{:content_type, :fields}, :data_template, :state, :form_mapping]
        )

      trigger =
        insert(:trigger_history,
          pipeline: pipeline,
          data: %{
            "#{content_type_field_1.field.id}" => "John Doe",
            "#{content_type_field_2.field.id}" => "John Doe Jr."
          }
        )

      before_count = Instance |> Repo.all() |> length
      response = PipelineRunner.create_instances(trigger)

      instances =
        response.instances |> Enum.map(fn x -> x.content_type.name end) |> List.to_string()

      assert before_count + 2 == Instance |> Repo.all() |> length
      assert response.trigger == trigger
      assert instances =~ c_type1.name
      assert instances =~ c_type2.name
      assert response.user.id == trigger.creator.id
    end

    test "creates instance and returns a map with created instance when trigger does not have creator ID" do
      pipeline = insert(:pipeline)
      flow = insert(:flow)
      insert(:state, flow: flow, order: 1)
      insert(:state, flow: flow, order: 2)
      content_type1 = insert(:content_type, flow: flow)
      content_type2 = insert(:content_type, flow: flow)
      pipe_stage1 = insert(:pipe_stage, pipeline: pipeline, content_type: content_type1)
      pipe_stage2 = insert(:pipe_stage, pipeline: pipeline, content_type: content_type2)
      content_type_field_1 = insert(:content_type_field, content_type: content_type1)
      content_type_field_2 = insert(:content_type_field, content_type: content_type2)

      insert(:form_mapping, pipe_stage: pipe_stage1)
      insert(:form_mapping, pipe_stage: pipe_stage2)

      pipeline =
        Repo.preload(pipeline,
          stages: [{:content_type, :fields}, :data_template, :state, :form_mapping]
        )

      trigger =
        insert(:trigger_history,
          pipeline: pipeline,
          creator: nil,
          data: %{
            "#{content_type_field_1.field.id}" => "John Doe",
            "#{content_type_field_2.field.id}" => "John Doe Jr."
          }
        )

      before_count = Instance |> Repo.all() |> length
      response = PipelineRunner.create_instances(trigger)

      instances =
        response.instances |> Enum.map(fn x -> x.content_type.name end) |> List.to_string()

      instance = List.first(response.instances)

      assert before_count + 2 == Instance |> Repo.all() |> length
      assert response.trigger == trigger
      assert instances =~ content_type1.name
      assert instances =~ content_type2.name
      assert instance.creator_id == nil
    end
  end

  describe "instances_created?/1" do
    # FIXME
    @tag :skip
    test "returns true when the list of instances contains only instance structs" do
      # FIX: Use unique email for this test
      user = insert(:user, email: "instances-created-true-#{System.unique_integer()}@test.com")
      instance1 = insert(:instance, creator: user)
      instance2 = insert(:instance, creator: user)

      response = PipelineRunner.instances_created?(%{instances: [instance1, instance2]})
      assert response == true
    end

    # FIXME
    @tag :skip
    test "returns false when the list of instances contains error tuples also" do
      instance1 = insert(:instance)

      response =
        PipelineRunner.instances_created?(%{instances: [instance1, {:error, %Ecto.Changeset{}}]})

      assert response == false
    end
  end

  # describe "build/1" do
  #   test "builds the list of instances in the map and returns a map with
  # with the instances and build responses when input map has a user key" do
  #     user = insert(:user)
  #     instances = insert_list(3, :instance)
  #     count_before = History |> Repo.all() |> length()
  #     response = PipelineRunner.build(%{instances: instances, user: user})

  #     instance_ids = instances |> Enum.map(fn x -> x.id end)

  #     response_instance_ids =
  #       response.builds |> Enum.map(fn %{instance: instance} -> instance.id end)

  #     assert count_before + 3 == History |> Repo.all() |> length()
  #     assert response.instances == instances
  #     assert response.user == user
  #     assert response_instance_ids == instance_ids
  #   end

  #   test "builds the list of instances in the map and returns a map with with the
  # instances and build responses when input map does not have a user key" do
  #     instances = insert_list(3, :instance)
  #     count_before = History |> Repo.all() |> length()
  #     response = PipelineRunner.build(%{instances: instances})

  #     instance_ids = instances |> Enum.map(fn x -> x.id end)

  #     response_instance_ids =
  #       response.builds |> Enum.map(fn %{instance: instance} -> instance.id end)

  #     assert count_before + 3 == History |> Repo.all() |> length()
  #     assert response.instances == instances
  #     assert response_instance_ids == instance_ids
  #   end
  # end

  describe "build_failed?/1" do
    # FIXME
    @tag :skip
    test "returns a map with list of maps of build failed instances and their error codes when there are failed builds" do
      instances = insert_list(3, :instance)

      builds = Enum.map(instances, fn x -> %{instance: x, response: {"", Enum.random(0..3)}} end)

      failed_build_instance_ids =
        builds
        |> Stream.filter(fn %{response: {_, x}} -> x != 0 end)
        |> Stream.map(fn x -> x.instance.id end)
        |> Enum.to_list()

      response = PipelineRunner.build_failed?(%{builds: builds})
      error_codes = Enum.map(response.failed_builds, fn x -> x.error_code end)
      failed_instance_ids = Enum.map(response.failed_builds, fn x -> x.doc_failed_document_id end)

      refute 0 in error_codes
      refute nil in response.failed_builds
      assert failed_instance_ids == failed_build_instance_ids
    end

    # FIXME
    @tag :skip
    test "returns a map with empty list for the faile_builds key when there are no failed builds" do
      instances = insert_list(3, :instance)
      builds = Enum.map(instances, fn x -> %{instance: x, response: {"", 0}} end)

      response = PipelineRunner.build_failed?(%{builds: builds})

      assert response.failed_builds == []
    end
  end

  describe "zip_builds/1" do
    # FIXME
    @tag :skip
    test "builds a zip file" do
      instance1 = insert(:instance)
      instance2 = insert(:instance)
      path = fn instance_id -> "uploads/contents/#{instance_id}" end
      file_path1 = path.(instance1.instance_id)
      file_path2 = path.(instance2.instance_id)
      File.mkdir_p!(file_path1)
      File.mkdir_p!(file_path2)
      File.write!(file_path1 <> "/final.pdf", "content")
      File.write!(file_path2 <> "/final.pdf", "content")

      org_id = instance1.content_type.organisation_id

      insert(:build_history, content: instance1)
      insert(:build_history, content: instance2)
      # TODO check this part refactor if needed
      Mox.expect(ExAwsMock, :request, fn %ExAws.S3.Upload{} ->
        {:ok, %ExAws.Operation.S3{}}
      end)

      response = PipelineRunner.zip_builds(%{instances: [instance1, instance2]})
      zip_file_path = "organisations/#{org_id}/pipe_builds/#{response.zip_file}"
      assert File.exists?(zip_file_path) == true

      File.rm_rf(file_path1)
      File.rm_rf(file_path2)
      File.rm(zip_file_path)
    end
  end
end
