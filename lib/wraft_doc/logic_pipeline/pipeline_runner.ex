defmodule WraftDoc.PipelineRunner do
  @moduledoc """
  Opus Pipeline for docs creation.
  """

  use Opus.Pipeline

  alias WraftDoc.Account
  alias WraftDoc.Client.Minio
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise
  alias WraftDoc.Forms
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Repo

  step(:preload_pipeline_and_stages)
  check(:pipeline_exists?, error_message: :pipeline_not_found)
  check(:form_mapping_exists?, error_message: :form_mapping_not_complete)
  step(:create_instances)
  check(:instances_created?, error_message: :instance_failed)
  step(:build)
  step(:build_failed?)
  step(:zip_builds)

  @doc """
  Preload the pipeline and its stages and the content types and fields etc.
  """
  @spec preload_pipeline_and_stages(TriggerHistory.t()) :: TriggerHistory.t() | nil
  def preload_pipeline_and_stages(%TriggerHistory{} = trigger) do
    Repo.preload(trigger,
      pipeline: [stages: [{:content_type, :fields}, :data_template, :state, :form_mapping]]
    )
  end

  def preload_pipeline_and_stages(_), do: nil

  @doc """
  Check if the pipeline exists or not.
  """
  @spec pipeline_exists?(TriggerHistory.t()) :: boolean()
  def pipeline_exists?(%{pipeline: %Pipeline{}}), do: true
  def pipeline_exists?(_), do: false

  @doc """
    Check if form mappings exist or not
  """
  @spec form_mapping_exists?(TriggerHistory.t()) :: boolean()
  def form_mapping_exists?(%{pipeline: %{stages: stages}}) do
    Enum.all?(stages, &(&1.form_mapping != nil))
  end

  def form_mapping_exists?(_), do: false

  @doc """
  Creates instances for all the stages of the pipeline.
  """
  @spec create_instances(TriggerHistory.t()) :: map()
  def create_instances(%{data: data, creator_id: u_id, pipeline: %{stages: stages}} = trigger)
      when is_nil(u_id) == false do
    user = Account.get_user(u_id)
    type = Instance.types()[:pipeline_api]

    instances =
      Enum.map(stages, fn %{
                            content_type: c_type,
                            data_template: d_temp,
                            form_mapping: form_mapping
                          } ->
        try do
          transformed_data =
            case data["trigger_type"] do
              "webhook" -> Forms.transform_trigger_data_by_mapping(form_mapping, data)
              _ -> Forms.transform_data_by_mapping(form_mapping, data)
            end

          params =
            transformed_data
            |> Documents.do_create_instance_params(d_temp)
            |> Map.merge(%{"type" => type, "doc_settings" => %{}})

          Documents.create_instance(
            user,
            c_type,
            Enterprise.get_final_state(c_type.flow_id),
            params
          )
        rescue
          e ->
            error_message = Exception.message(e)
            %{failed: true, error: error_message, content_type_id: c_type.id, stage_index: nil}
        end
      end)

    %{trigger: trigger, instances: instances, user: user}
  end

  def create_instances(%{data: data, creator_id: nil, pipeline: %{stages: stages}} = trigger) do
    type = Instance.types()[:pipeline_hook]

    instances =
      Enum.map(stages, fn %{
                            content_type: c_type,
                            data_template: d_temp,
                            form_mapping: form_mapping
                          } ->
        transformed_data = Forms.transform_data_by_mapping(form_mapping, data)

        params =
          transformed_data
          |> Documents.do_create_instance_params(d_temp)
          |> Map.merge(%{
            "type" => type,
            "doc_settings" => %{}
          })

        Documents.create_instance(c_type, Enterprise.get_final_state(c_type.flow_id), params)
      end)

    %{trigger: trigger, instances: instances}
  end

  def create_instances(_), do: {:error, :invalid_data}

  @doc """
  Check if at least one instance was successfully created.
  Allows partial success - if some instances fail, we continue to build step.
  """
  @spec instances_created?(map()) :: boolean()
  def instances_created?(%{instances: instances}) do
    successful_count =
      Enum.count(instances, fn
        x when is_struct(x) -> true
        _ -> false
      end)

    successful_count > 0
  end

  @doc """
  Build all stages.
  Filters out instances that failed to be created, only builds successful ones.
  """
  # TODO - write tests - Tests commented to use mock
  @spec build(map()) :: map()
  def build(%{instances: instances, user: user} = input) do
    successful_instances =
      Enum.filter(instances, fn
        %{failed: true} -> false
        x when is_struct(x) -> true
        _ -> false
      end)

    builds =
      Enum.map(successful_instances, fn instance ->
        try do
          resp = Documents.bulk_build(user, instance, instance.content_type.layout)
          %{instance: instance, response: resp}
        rescue
          e ->
            # Catch exceptions during build and convert to error response
            error_message = Exception.message(e)
            %{instance: instance, response: {error_message, 1}}
        end
      end)

    failed_creations =
      instances
      |> Enum.with_index()
      |> Enum.filter(fn
        {%{failed: true}, _index} -> true
        {x, _index} when is_struct(x) -> false
        _ -> true
      end)
      |> Enum.map(fn
        {%{failed: true, error: error_message, content_type_id: c_type_id}, index} ->
          %{
            doc_failed_document_id: nil,
            error_code: 1,
            error_message: "Instance creation failed: #{error_message}",
            stage_index: index,
            content_type_id: c_type_id
          }

        {other, index} ->
          %{
            doc_failed_document_id: nil,
            error_code: 1,
            error_message: "Instance creation failed: #{inspect(other, limit: 1)}",
            stage_index: index
          }
      end)

    input
    |> Map.put(:builds, builds)
    |> Map.put(:instance_creation_failures, failed_creations)
  end

  def build(%{instances: instances} = input) do
    successful_instances =
      Enum.filter(instances, fn
        %{failed: true} -> false
        x when is_struct(x) -> true
        _ -> false
      end)

    builds =
      Enum.map(successful_instances, fn instance ->
        try do
          resp = Documents.bulk_build(instance, instance.content_type.layout)
          %{instance: instance, response: resp}
        rescue
          e ->
            error_message = Exception.message(e)
            %{instance: instance, response: {error_message, 1}}
        end
      end)

    failed_creations =
      instances
      |> Enum.with_index()
      |> Enum.filter(fn
        {%{failed: true}, _index} -> true
        {x, _index} when is_struct(x) -> false
        _ -> true
      end)
      |> Enum.map(fn
        {%{failed: true, error: error_message, content_type_id: c_type_id}, index} ->
          %{
            doc_failed_document_id: nil,
            error_code: 1,
            error_message: "Instance creation failed: #{error_message}",
            stage_index: index,
            content_type_id: c_type_id
          }

        {other, index} ->
          %{
            doc_failed_document_id: nil,
            error_code: 1,
            error_message: "Instance creation failed: #{inspect(other, limit: 1)}",
            stage_index: index
          }
      end)

    input
    |> Map.put(:builds, builds)
    |> Map.put(:instance_creation_failures, failed_creations)
  end

  @doc """
  Check if all the builds were successfull or not
  Combines both build failures and instance creation failures.
  """
  @spec build_failed?(map()) :: map()
  def build_failed?(%{builds: builds} = input) do
    failed_builds =
      builds
      |> Stream.map(fn
        %{response: {_, 0}} ->
          nil

        %{instance: instance, response: {error_message, error_code}} ->
          %{
            doc_failed_document_id: instance.id,
            error_code: error_code,
            error_message: error_message
          }
      end)
      |> Stream.filter(fn x -> x != nil end)
      |> Enum.to_list()

    instance_creation_failures = Map.get(input, :instance_creation_failures, [])
    all_failed_builds = failed_builds ++ instance_creation_failures

    Map.put(input, :failed_builds, all_failed_builds)
  end

  @doc """
  Zip all the builds.
  """
  @spec zip_builds(map()) :: map()
  def zip_builds(%{instances: instances, failed_builds: failed_builds} = input) do
    failed_instance_ids =
      failed_builds
      |> Enum.map(&Map.get(&1, :doc_failed_document_id))
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    successful_instances =
      Enum.filter(instances, fn
        %{failed: true} -> false
        x when is_struct(x) -> not MapSet.member?(failed_instance_ids, x.id)
        _ -> false
      end)

    zip_file =
      if length(successful_instances) > 0 do
        org_id = List.first(successful_instances).content_type.organisation_id

        builds =
          successful_instances
          |> Stream.map(fn x -> x |> Documents.get_built_document() |> Map.get(:build) end)
          |> Stream.filter(fn x -> x != nil end)
          |> Enum.map(&String.to_charlist/1)

        time = DateTime.to_iso8601(Timex.now())
        zip_name = "builds-#{time}.zip"
        dest_path = "organisations/#{org_id}/pipe_builds/#{zip_name}"
        :zip.create(zip_name, builds)
        File.mkdir_p!("organisations/#{org_id}/pipe_builds/")
        System.cmd("cp", [zip_name, dest_path])
        Minio.upload_file(dest_path)
        File.rm(zip_name)
        Enum.each(successful_instances, &(&1.instance_id |> content_dir(org_id) |> File.rm_rf()))
        zip_name
      else
        nil
      end

    Map.put(input, :zip_file, zip_file)
  end

  def zip_builds(%{instances: instances} = input) do
    successful_instances =
      Enum.filter(instances, fn
        %{failed: true} -> false
        x when is_struct(x) -> true
        _ -> false
      end)

    if length(successful_instances) > 0 do
      org_id = List.first(successful_instances).content_type.organisation_id

      builds =
        successful_instances
        |> Stream.map(fn x -> x |> Documents.get_built_document() |> Map.get(:build) end)
        |> Stream.filter(fn x -> x != nil end)
        |> Enum.map(&String.to_charlist/1)

      time = DateTime.to_iso8601(Timex.now())
      zip_name = "builds-#{time}.zip"
      dest_path = "organisations/#{org_id}/pipe_builds/#{zip_name}"
      :zip.create(zip_name, builds)
      File.mkdir_p!("organisations/#{org_id}/pipe_builds/")
      System.cmd("cp", [zip_name, dest_path])
      Minio.upload_file(dest_path)
      File.rm(zip_name)
      Enum.each(successful_instances, &(&1.instance_id |> content_dir(org_id) |> File.rm_rf()))
      Map.put(input, :zip_file, zip_name)
    else
      Map.put(input, :zip_file, nil)
    end
  end

  defp content_dir(instance_id, org_id),
    do: Path.join(File.cwd!(), "organisations/#{org_id}/contents/#{instance_id}")
end
