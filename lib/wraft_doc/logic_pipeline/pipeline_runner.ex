defmodule WraftDoc.PipelineRunner do
  @moduledoc """
  Opus Pipeline for docs creation.
  """

  use Opus.Pipeline

  alias WraftDoc.Account
  alias WraftDoc.Assets
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
  @spec create_instances(TriggerHistory.t()) :: map
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
        transformed_data = Forms.transform_data_by_mapping(form_mapping, data)

        params =
          transformed_data |> Documents.do_create_instance_params(d_temp) |> Map.put("type", type)

        Documents.create_instance(
          user,
          c_type,
          Enterprise.get_final_state(c_type.flow_id),
          params
        )
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
          transformed_data |> Documents.do_create_instance_params(d_temp) |> Map.put("type", type)

        Documents.create_instance(c_type, Enterprise.get_final_state(c_type.flow_id), params)
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
  @spec build(map()) :: map()
  # def build(%{instances: instances, user: user}), do: IO.inspect(data, label: "build")
  def build(%{instances: instances, user: user} = input) do
    builds =
      Enum.map(instances, fn instance ->
        instance = Repo.preload(instance, content_type: [{:layout, :assets}])
        layout = Assets.preload_asset(instance.content_type.layout)
        resp = Documents.bulk_build(user, instance, layout)
        %{instance: instance, response: resp}
      end)

    Map.put(input, :builds, builds)
  end

  def build(%{instances: instances} = input) do
    builds =
      Enum.map(instances, fn instance ->
        instance = Repo.preload(instance, content_type: [{:layout, :assets}])
        layout = Assets.preload_asset(instance.content_type.layout)
        resp = Documents.bulk_build(instance, layout)
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
    org_id = List.first(instances).content_type.organisation_id

    builds =
      instances
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
    # Delete all the generated content folder
    Enum.each(instances, &(&1.instance_id |> content_dir(org_id) |> File.rm_rf()))
    Map.put(input, :zip_file, zip_name)
  end

  defp content_dir(instance_id, org_id),
    do: Path.join(File.cwd!(), "organisations/#{org_id}/contents/#{instance_id}")
end
