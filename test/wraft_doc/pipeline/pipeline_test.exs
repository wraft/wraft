defmodule WraftDoc.Pipeline.PipelineTest do
  use WraftDoc.DataCase, async: false
  import WraftDoc.Factory
  import Mox

  @moduletag :document

  alias WraftDoc.Documents
  alias WraftDoc.Documents.InstanceApprovalSystem
  alias WraftDoc.Fields
  alias WraftDoc.Fields.Field
  alias WraftDoc.Fields.Field
  alias WraftDoc.Pipelines
  alias WraftDoc.Pipelines.Stages
  alias WraftDoc.Pipelines.Stages.Stage
  alias WraftDoc.Pipelines.TriggerHistories
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Repo
  setup :verify_on_exit!

  describe "create_pipeline/2" do
    test "creates pipeline with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "name" => "pipeline",
        "api_route" => "www.crm.com",
        "source" => "WraftForms",
        "source_id" => "82850951-ab5d-40d3-89ce-40b321d63b81",
        "organisation_id" => organisation.id,
        "stages" => [
          %{
            "content_type_id" => c_type.id,
            "data_template_id" => d_temp.id
          }
        ]
      }

      pipeline = Pipelines.create_pipeline(user, attrs)

      [%{content_type: content_type, data_template: data_template}] = pipeline.stages

      assert pipeline.name == "pipeline"
      assert pipeline.api_route == "www.crm.com"
      assert pipeline.source == "WraftForms"
      assert pipeline.source_id == "82850951-ab5d-40d3-89ce-40b321d63b81"
      assert content_type.name == c_type.name
      assert data_template.title == d_temp.title
    end

    test "returns error with invalid attrs" do
      user = insert(:user_with_organisation)
      {:error, changeset} = Pipelines.create_pipeline(user, %{})
      assert %{name: ["can't be blank"], api_route: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "create_pipe_stage/3" do
    test "creates pipe stage with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline, organisation: organisation)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      {:ok, stage} = Stages.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert stage.content_type_id == c_type.id
      assert stage.data_template_id == d_temp.id
      assert stage.pipeline_id == pipeline.id
      assert stage.creator_id == user.id
    end

    test "returns unique constraint error with same pipeline and data template ID" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      pipeline = insert(:pipeline, organisation: organisation)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)
      insert(:pipe_stage, pipeline: pipeline, content_type: c_type, data_template: d_temp)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      {:error, changeset} = Stages.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert %{data_template_id: ["Already added.!"]} == errors_on(changeset)
    end

    test "returns nil with non-existent UUIDs of datas" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)

      attrs = %{
        "state_id" => Ecto.UUID.generate(),
        "content_type_id" => Ecto.UUID.generate(),
        "data_template_id" => Ecto.UUID.generate()
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      stage = Stages.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert stage == nil
    end

    test "returns nil with wrong data" do
      user = insert(:user)
      pipeline = insert(:pipeline)

      attrs = %{"state_id" => 1, "content_type_id" => 2, "data_template_id" => 3}

      count_before =
        Stage
        |> Repo.all()
        |> length()

      stage = Stages.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert stage == nil
    end

    test "returns nil when all required datas are not given" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      state = insert(:state)
      attrs = %{"state_id" => state.id}

      count_before =
        Stage
        |> Repo.all()
        |> length()

      stage = Stages.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert stage == nil
    end

    test "returns nil when given datas does not belong to current user's organsation" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)
      c_type = insert(:content_type)
      d_temp = insert(:data_template)
      state = insert(:state)

      attrs = %{
        "state_id" => state.id,
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      response = Stages.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert response == nil
    end
  end

  describe "pipeline_index/2" do
    test "returns list of pipelines in the users organisation only" do
      user = insert(:user_with_organisation)
      pipeline1 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline2 = insert(:pipeline)
      %{entries: pipelines} = Pipelines.pipeline_index(user, %{})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert pipeline_names =~ pipeline1.name
      refute pipeline_names =~ pipeline2.name
    end

    test "returns nil with invalid attrs" do
      response = Pipelines.pipeline_index(nil, %{})
      assert response == nil
    end

    test "pipeline index lists the pipeline data" do
      user = insert(:user_with_organisation)
      pipeline1 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline2 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      %{entries: pipelines} = Pipelines.pipeline_index(user, %{})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert pipeline_names =~ pipeline1.name
      assert pipeline_names =~ pipeline2.name
    end

    test "filters by name" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Pipelines.pipeline_index(user, %{"name" => "First"})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert pipeline_names =~ pipeline1.name
      refute pipeline_names =~ pipeline2.name
    end

    test "returns an empty list when there are no matches for the name keyword" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Pipelines.pipeline_index(user, %{"name" => "Does Not Exist"})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      refute pipeline_names =~ pipeline1.name
      refute pipeline_names =~ pipeline2.name
    end

    test "sorts by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Pipelines.pipeline_index(user, %{"sort" => "name"})

      assert List.first(pipelines).name == pipeline1.name
      assert List.last(pipelines).name == pipeline2.name
    end

    test "sorts by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Pipelines.pipeline_index(user, %{"sort" => "name_desc"})

      assert List.first(pipelines).name == pipeline2.name
      assert List.last(pipelines).name == pipeline1.name
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:56:34],
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:57:34],
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Pipelines.pipeline_index(user, %{"sort" => "inserted_at"})

      assert List.first(pipelines).name == pipeline1.name
      assert List.last(pipelines).name == pipeline2.name
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:56:34],
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:57:34],
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Pipelines.pipeline_index(user, %{"sort" => "inserted_at_desc"})

      assert List.first(pipelines).name == pipeline2.name
      assert List.last(pipelines).name == pipeline1.name
    end
  end

  # MOVE
  describe "create_pipeline_job/1" do
    test "Creates a background job to run a pipeline" do
      current_user = insert(:user)
      trigger_history = insert(:trigger_history)

      assert {:ok, _dd} = TriggerHistories.create_pipeline_job(current_user, trigger_history)
    end
  end

  # describe "bulk_doc_build/6" do
  #   test "Bulk build function" do
  #     user = insert(:user)
  #     c_type = insert(:content_type)
  #     state = insert(:state)
  #     d_temp = insert(:data_template)
  #     # k = Faker.Person.first_name()
  #     v = Faker.Person.last_name()
  #     map = %{"hey" => v}
  #     path = "/home/functionary/Downloads/sample4.csv"
  #     bulk_doc_build = Documents.bulk_doc_build(user, c_type, state, d_temp, map, path)
  #     IO.inspect(bulk_doc_build)
  #   end
  # end
  describe "get_pipeline/2" do
    test "returns the pipeline in the user's organisation with given id" do
      user = insert(:user_with_organisation)
      pipe = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline = Pipelines.get_pipeline(user, pipe.id)
      assert pipeline.name == pipe.name
      assert pipeline.id == pipe.id
    end

    test "returns nil when pipeline does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)
      response = Pipelines.get_pipeline(user, pipeline.id)
      assert response == nil
    end

    test "returns nil for non existent pipeline" do
      user = insert(:user_with_organisation)
      response = Pipelines.get_pipeline(user, Ecto.UUID.generate())
      assert response == nil
    end

    test "returns nil for invalid data" do
      response = Pipelines.get_pipeline(nil, Ecto.UUID.generate())
      assert response == nil
    end
  end

  describe "show_pipeline/2" do
    test "returns the pipeline in the user's organisation with given id" do
      user = insert(:user_with_organisation)
      pipe = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline = Pipelines.show_pipeline(user, pipe.id)
      assert pipeline.name == pipe.name
      assert pipeline.id == pipe.id
    end

    test "returns nil when pipeline does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)
      response = Pipelines.show_pipeline(user, pipeline.id)
      assert response == nil
    end

    test "returns nil for non existent pipeline" do
      user = insert(:user_with_organisation)
      response = Pipelines.show_pipeline(user, Ecto.UUID.generate())
      assert response == nil
    end

    test "returns nil for invalid data" do
      response = Pipelines.show_pipeline(nil, Ecto.UUID.generate())
      assert response == nil
    end
  end

  describe "pipeline_update/3" do
    test "updates pipeline with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "name" => "pipeline",
        "api_route" => "www.crm.com",
        "stages" => [
          %{
            "content_type_id" => c_type.id,
            "data_template_id" => d_temp.id
          }
        ]
      }

      pipeline = Pipelines.pipeline_update(pipeline, user, attrs)
      [stage] = pipeline.stages
      assert pipeline.name == "pipeline"
      assert pipeline.api_route == "www.crm.com"
      assert stage.content_type.name == c_type.name
      assert stage.data_template.title == d_temp.title
    end

    test "returns error with invalid attrs" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      {:error, changeset} = Pipelines.pipeline_update(pipeline, user, %{name: ""})
      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end

    test "returns nil with wrong data" do
      response = Pipelines.pipeline_update(nil, nil, %{})
      assert response == nil
    end
  end

  describe "delete_pipeline/1" do
    test "deletes pipeline with correct data" do
      pipeline = insert(:pipeline)
      {:ok, _pipeline} = Pipelines.delete_pipeline(pipeline)

      refute Repo.get(WraftDoc.Pipelines.Pipeline, pipeline.id)
    end

    test "returns nil with invalid data" do
      assert nil == Pipelines.delete_pipeline(nil)
    end
  end

  describe "get_pipe_stage/2" do
    test "returns the pipe stage in the user's organisation with valid IDs and user struct" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      stage = insert(:pipe_stage, pipeline: pipeline)
      response = Stages.get_pipe_stage(user, stage.id)
      assert response.pipeline_id == pipeline.id
      assert response.id == stage.id
    end

    test "returns nil when stage does not belong to user's organisation" do
      user = insert(:user_with_organisation)
      stage = insert(:pipe_stage)
      response = Stages.get_pipe_stage(user, stage.id)
      assert response == nil
    end

    test "returns nil with non-existent IDs" do
      user = insert(:user_with_organisation)
      response = Stages.get_pipe_stage(user, Ecto.UUID.generate())
      assert response == nil
    end

    test "returns nil invalid data" do
      response = Stages.get_pipe_stage(nil, Ecto.UUID.generate())
      assert response == nil
    end
  end

  describe "update_pipe_stage/3" do
    test "updates pipe stage with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      stage = insert(:pipe_stage, state: state)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      {:ok, updated_stage} = Stages.update_pipe_stage(user, stage, attrs)

      assert updated_stage.id == stage.id
      assert updated_stage.content_type_id == c_type.id
      assert updated_stage.data_template_id == d_temp.id
      assert updated_stage.state_id == state.id
    end

    test "returns unique constraint error when a stage is updated with same pipeline and content type ID of another existing stage" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)
      insert(:pipe_stage, pipeline: pipeline, data_template: d_temp, content_type: c_type)
      stage = insert(:pipe_stage, pipeline: pipeline, content_type: c_type)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      {:error, changeset} = Stages.update_pipe_stage(user, stage, attrs)

      assert %{data_template_id: ["Already added.!"]} == errors_on(changeset)
    end

    test "returns nil with non-existent UUIDs of datas" do
      user = insert(:user_with_organisation)
      stage = insert(:pipe_stage)

      attrs = %{
        "state_id" => Ecto.UUID.generate(),
        "content_type_id" => Ecto.UUID.generate(),
        "data_template_id" => Ecto.UUID.generate()
      }

      stage = Stages.update_pipe_stage(user, stage, attrs)

      assert stage == nil
    end

    test "returns nil with wrong data" do
      user = insert(:user)
      stage = insert(:pipe_stage)
      attrs = %{"state_id" => 1, "content_type_id" => 2, "data_template_id" => 3}
      stage = Stages.update_pipe_stage(user, stage, attrs)

      assert stage == nil
    end

    test "returns nil when all required datas are not given" do
      user = insert(:user)
      stage = insert(:pipe_stage)
      state = insert(:state)
      attrs = %{"state_id" => state.id}

      stage = Stages.update_pipe_stage(user, stage, attrs)

      assert stage == nil
    end

    test "returns nil when given datas does not belong to current user's organsation" do
      user = insert(:user_with_organisation)
      stage = insert(:pipe_stage)
      c_type = insert(:content_type)
      d_temp = insert(:data_template)
      state = insert(:state)

      attrs = %{
        "state_id" => state.id,
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      response = Stages.update_pipe_stage(user, stage, attrs)

      assert response == nil
    end
  end

  describe "delete_pipe_stage/1" do
    test "deletes stage with correct data" do
      stage = insert(:pipe_stage)
      {:ok, _stage} = Stages.delete_pipe_stage(stage)

      refute Repo.get(Stage, stage.id)
    end

    test "returns nil with invalid data" do
      assert nil == Stages.delete_pipe_stage(nil)
    end
  end

  describe "preload_stage_details/1" do
    test "preloads the details of a stage" do
      stage = insert(:pipe_stage)
      preloaded_stage = Stages.preload_stage_details(stage)
      assert preloaded_stage.content_type.name == stage.content_type.name
      assert preloaded_stage.pipeline.name == stage.pipeline.name
      assert preloaded_stage.state.state == stage.state.state
      assert preloaded_stage.data_template.title == stage.data_template.title
    end
  end

  describe "create_trigger_history/3" do
    test "creates trigger history with valid attrs" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      data = %{name: "John Doe"}
      state = TriggerHistory.states()[:enqued]

      count_before =
        TriggerHistory
        |> Repo.all()
        |> length

      {:ok, trigger} = TriggerHistories.create_trigger_history(user, pipeline, data)

      count_after =
        TriggerHistory
        |> Repo.all()
        |> length

      assert count_before + 1 == count_after
      assert trigger.data == %{name: "John Doe"}
      assert trigger.pipeline_id == pipeline.id
      assert trigger.creator_id == user.id
      assert trigger.state == state
    end

    test "returns error with invalid attrs" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      data = "wrong type"

      count_before =
        TriggerHistory
        |> Repo.all()
        |> length

      {:error, changeset} = TriggerHistories.create_trigger_history(user, pipeline, data)

      count_after =
        TriggerHistory
        |> Repo.all()
        |> length

      assert count_before == count_after
      assert %{data: ["is invalid"]} == errors_on(changeset)
    end

    test "retruns nil with wrong data" do
      response = TriggerHistories.create_trigger_history(nil, nil, %{})
      assert response == nil
    end
  end

  describe "create_instance_content_types" do
    @describetag :cict
    test "creates relations for approval systems of content type" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      flow = insert(:flow, organisation: organisation)
      insert(:approval_system, flow: flow)
      insert(:approval_system, flow: flow)
      content_type = insert(:content_type, flow: flow, organisation: organisation)
      instance = insert(:instance, content_type: content_type)

      count_before =
        InstanceApprovalSystem
        |> Repo.all()
        |> length()

      Documents.create_instance_approval_systems(content_type, instance)

      count_after =
        InstanceApprovalSystem
        |> Repo.all()
        |> length()

      assert count_before + 2 == count_after
    end
  end

  describe "get_trigger_histories_of_a_pipeline/2" do
    test "returns trigger history of only the given pipeline" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline)

      %{entries: trigger_history_index} =
        TriggerHistories.get_trigger_histories_of_a_pipeline(pipeline, %{page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      assert trigger_history_ids =~ trigger_history_2.id
    end

    test "returns nil with invalid attrs" do
      trigger_history_index =
        TriggerHistories.get_trigger_histories_of_a_pipeline("invalid attrs", %{page: 1})

      assert trigger_history_index == nil
    end
  end

  describe "trigger_history_index/2" do
    test "trigger history index the trigger history data" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline)

      %{entries: trigger_history_index} = TriggerHistories.trigger_history_index(user, %{page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      assert trigger_history_ids =~ trigger_history_2.id
    end

    test "returns nil with invalid attrs" do
      trigger_history_index = TriggerHistories.trigger_history_index("invalid attrs", %{page: 1})
      assert trigger_history_index == nil
    end

    test "returns trigger history from pipeline in user's organisation only" do
      user = insert(:user_with_organisation)
      pipeline_1 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline_2 = insert(:pipeline)
      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} = TriggerHistories.trigger_history_index(user, %{page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      refute trigger_history_ids =~ trigger_history_2.id
    end

    test "filter by pipeline name" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"pipeline_name" => "First", page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      refute trigger_history_ids =~ trigger_history_2.id
    end

    test "returns an empty list when there are no matches for the pipeline_name keyword" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      insert(:trigger_history, pipeline: pipeline_1)
      insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{
          "pipeline_name" => "Does Not Exist",
          page: 1
        })

      assert [] == trigger_history_index
    end

    test "filter by status" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, state: 1, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"status" => 1, page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      refute trigger_history_ids =~ trigger_history_2.id
    end

    test "returns an empty list when there are no matches for the status keyword" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      insert(:trigger_history, state: 1, pipeline: pipeline)
      insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"status" => 3, page: 1})

      assert [] == trigger_history_index
    end

    test "sorts by pipeline_name in ascending order when sort key is pipeline_name" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"sort" => "pipeline_name", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_1.id
      assert List.last(trigger_history_index).id == trigger_history_2.id
    end

    test "sorts by pipeline_name in descending order when sort key is pipeline_name_desc" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"sort" => "pipeline_name_desc", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_2.id
      assert List.last(trigger_history_index).id == trigger_history_1.id
    end

    test "sorts by status in ascending order when sort key is status" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, state: 1, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"sort" => "status", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_1.id
      assert List.last(trigger_history_index).id == trigger_history_2.id
    end

    test "sorts by status in descending order when sort key is status_desc" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, state: 1, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"sort" => "status_desc", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_2.id
      assert List.last(trigger_history_index).id == trigger_history_1.id
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))

      trigger_history_1 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:56:34], pipeline: pipeline)

      trigger_history_2 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:57:34], pipeline: pipeline)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"sort" => "inserted_at", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_1.id
      assert List.last(trigger_history_index).id == trigger_history_2.id
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))

      trigger_history_1 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:56:34], pipeline: pipeline)

      trigger_history_2 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:57:34], pipeline: pipeline)

      %{entries: trigger_history_index} =
        TriggerHistories.trigger_history_index(user, %{"sort" => "inserted_at_desc", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_2.id
      assert List.last(trigger_history_index).id == trigger_history_1.id
    end
  end

  describe "create_field/2" do
    test "creates a field with valid attrs" do
      field_type = insert(:field_type)
      %{id: organisation_id} = insert(:organisation)

      params = %{
        name: "employee_name",
        meta: %{validations: [%{rule: "required", value: true}]},
        description: "Name of the employee",
        organisation_id: organisation_id
      }

      assert {:ok, %Field{id: _, name: "employee_name"} = field} =
               Fields.create_field(field_type, params)

      assert field.description == params.description
      assert field.meta == params.meta
    end

    test "returns error changeset with invalid attrs" do
      field_type = insert(:field_type)
      assert {:error, %Ecto.Changeset{}} = Fields.create_field(field_type, %{})
    end
  end
end
