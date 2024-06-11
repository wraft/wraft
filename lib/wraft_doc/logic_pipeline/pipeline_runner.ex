defmodule WraftDoc.PipelineRunner do
  @moduledoc """
  Opus Pipeline for docs creation.
  """

  use Opus.Pipeline

  alias WraftDoc.Account
  alias WraftDoc.Client.Minio
  alias WraftDoc.Document
  alias WraftDoc.Document.Instance
  alias WraftDoc.Document.Pipeline
  alias WraftDoc.Document.Pipeline.TriggerHistory
  alias WraftDoc.Enterprise
  alias WraftDoc.Repo

  step(:preload_pipeline_and_stages)
  check(:pipeline_exists?, error_message: :pipeline_not_found)
  check(:values_provided?, error_message: :values_unavailable)
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
    Repo.preload(trigger, pipeline: [stages: [{:content_type, :fields}, :data_template, :state]])
  end

  def preload_pipeline_and_stages(_), do: nil

  @doc """
  Check if the pipeline exists or not.
  """
  @spec pipeline_exists?(TriggerHistory.t()) :: boolean()
  def pipeline_exists?(%{pipeline: %Pipeline{}}), do: true
  def pipeline_exists?(_), do: false

  @doc """
  Check if the data provided includes all the requied fields of all stages of the pipeline.
  """
  @spec values_provided?(map) :: boolean()
  def values_provided?(%{data: data, pipeline: %Pipeline{stages: stages}}) do
    value =
      stages
      |> Enum.map(fn stage -> stage.content_type.fields end)
      |> List.flatten()
      |> Enum.map(fn c_type_field -> Map.has_key?(data, c_type_field.name) end)
      |> Enum.member?(false)

    !value
  end

  @doc """
  Creates instances for all the stages of the pipeline.
  """
  @spec create_instances(TriggerHistory.t()) :: map
  def create_instances(%{data: data, creator_id: u_id, pipeline: %{stages: stages}} = trigger)
      when is_nil(u_id) == false do
    user = Account.get_user(u_id)
    type = Instance.types()[:pipeline_api]

    instances =
      Enum.map(stages, fn %{content_type: c_type, data_template: d_temp} ->
        params = data |> Document.do_create_instance_params(d_temp) |> Map.put("type", type)
        Document.create_instance(user, c_type, Enterprise.get_final_state(c_type.flow_id), params)
      end)

    %{trigger: trigger, instances: instances, user: user}
  end

  def create_instances(%{data: data, creator_id: nil, pipeline: %{stages: stages}} = trigger) do
    type = Instance.types()[:pipeline_hook]

    instances =
      Enum.map(stages, fn %{content_type: c_type, data_template: d_temp} ->
        params = data |> Document.do_create_instance_params(d_temp) |> Map.put("type", type)
        Document.create_instance(c_type, Enterprise.get_final_state(c_type.flow_id), params)
      end)

    %{trigger: trigger, instances: instances}
  end

  def create_instances(_), do: {:error, :invalid_data}

  @doc """
  Check if all the instances were successfully created or not.
  """
  @spec instances_created?(map) :: boolean
  def instances_created?(%{instances: instances}) do
    instances
    |> Enum.find(fn
      x when is_struct(x) -> nil
      {k, _v} -> k == :error
    end)
    |> case do
      nil ->
        true

      _ ->
        false
    end
  end

  @doc """
  Build all stages.
  """
  # TODO - write tests - Tests commented to use mock
  @spec build(map) :: map
  def build(%{instances: instances, user: user} = input) do
    builds =
      Enum.map(instances, fn instance ->
        instance = Repo.preload(instance, content_type: [{:layout, :assets}])
        resp = Document.bulk_build(user, instance, instance.content_type.layout)
        %{instance: instance, response: resp}
      end)

    Map.put(input, :builds, builds)
  end

  def build(%{instances: instances} = input) do
    builds =
      Enum.map(instances, fn instance ->
        instance = Repo.preload(instance, content_type: [{:layout, :assets}])
        resp = Document.bulk_build(instance, instance.content_type.layout)
        %{instance: instance, response: resp}
      end)

    Map.put(input, :builds, builds)
  end

  @doc """
  Check if all the builds were successfull or not
  """
  @spec build_failed?(map) :: map
  def build_failed?(%{builds: builds} = input) do
    failed_builds =
      builds
      |> Stream.map(fn
        %{response: {_, 0}} ->
          nil

        %{instance: instance, response: {error_message, error_code}} ->
          %{
            doc_failed_instance_id: instance.id,
            error_code: error_code,
            error_message: error_message
          }
      end)
      |> Stream.filter(fn x -> x != nil end)
      |> Enum.to_list()

    Map.put(input, :failed_builds, failed_builds)
  end

  @doc """
  Zip all the builds.
  """
  @spec zip_builds(map) :: map
  def zip_builds(%{instances: instances} = input) do
    builds =
      instances
      |> Stream.map(fn x -> x |> Document.get_built_document(local: true) |> Map.get(:build) end)
      |> Stream.filter(fn x -> x != nil end)
      |> Enum.map(&String.to_charlist/1)

    time = DateTime.to_iso8601(Timex.now())
    zip_name = "builds-#{time}.zip"
    dest_path = "temp/pipe_builds/#{zip_name}"
    :zip.create(zip_name, builds)
    File.mkdir_p!("temp/pipe_builds/")
    System.cmd("cp", [zip_name, dest_path])
    Minio.upload_file(dest_path)
    File.rm(zip_name)
    # Delete all the generated content folder
    Enum.each(instances, &(&1.instance_id |> content_dir() |> File.rm_rf()))
    Map.put(input, :zip_file, zip_name)
  end

  defp content_dir(instance_id), do: Path.join(File.cwd!(), "uploads/contents/#{instance_id}")
end
