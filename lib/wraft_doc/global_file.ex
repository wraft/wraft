defmodule WraftDoc.GlobalFile do
  @moduledoc """
    Helper functions to files.
  """

  alias WraftDoc.Account.User
  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Frames.WraftJson, as: FrameWraftJson
  alias WraftDoc.TemplateAssets
  alias WraftDoc.Utils.FileHelper
  alias WraftDoc.Utils.FileValidator
  alias WraftDocWeb.Api.V1.FrameView
  alias WraftDocWeb.Api.V1.TemplateAssetView

  @doc """
  Import zip asset by pattern matching asset type.
  """
  @spec import_global_asset(User.t(), map()) ::
          {:ok, %{view: module(), template: String.t(), assigns: map()}} | {:error, String.t()}
  def import_global_asset(current_user, %{"file" => file, "type" => "frame"} = params) do
    with :ok <- FileHelper.validate_frame_file(file),
         {:ok, %Frame{} = frame} <- Frames.create_frame(current_user, params) do
      {:ok, %{view: FrameView, template: "create.json", assigns: %{frame: frame}}}
    end
  end

  def import_global_asset(current_user, %{"file" => file, "type" => "template_asset"} = params) do
    with :ok <- TemplateAssets.validate_template_asset_file(file),
         {:ok, params, file_binary} <-
           TemplateAssets.process_template_asset(params, :file, file),
         options <- TemplateAssets.format_opts(params),
         {:ok, result} <-
           TemplateAssets.import_template(current_user, file_binary, options) do
      {:ok,
       %{
         view: TemplateAssetView,
         template: "show_template.json",
         assigns: %{result: result}
       }}
    end
  end

  def import_global_asset(_, _), do: {:error, "Unsupported asset type"}

  defp validate_global_file(%{filename: file_name}) do
    file_extension = file_name |> Path.extname() |> String.downcase()

    if file_extension == ".zip" do
      :ok
    else
      {:error, "Invalid file type or file size exceeds limit"}
    end
  end

  @doc """
  Pre import global file returns metadata, file details and errors.
  """
  @spec pre_import_global_file(Plug.Upload.t()) :: {:ok, map()} | {:error, String.t()}
  def pre_import_global_file(%{path: file_path} = file) do
    with :ok <- validate_global_file(file),
         {:ok, file_binary} <- FileHelper.read_file_contents(file_path),
         {:ok, _} <- FileHelper.get_file_metadata(file) do
      %{wraft_json: nil, file_details: nil, errors: []}
      |> process_file_validation(file_path)
      |> process_file_metadata(file)
      |> process_wraft_json(file_binary)
      |> add_file_details(file)
      |> finalize_result()
    end
  end

  defp process_file_validation(result, file_path) do
    file_path
    |> FileValidator.validate_file()
    |> case do
      {:ok, _} ->
        result

      {:error, reason} ->
        add_error(result, "file_validation_error", reason)
    end
  end

  defp process_file_metadata(result, file) do
    case FileHelper.get_file_metadata(file) do
      {:ok, _metadata} -> result
      {:error, reason} -> add_error(result, "metadata_error", reason)
    end
  end

  defp process_wraft_json(result, file_binary) do
    case FileHelper.get_wraft_json(file_binary) do
      {:ok, wraft_json} ->
        validated_result = validate_wraft_json(result, wraft_json)
        Map.put(validated_result, :wraft_json, wraft_json)

      {:error, reason} ->
        add_error(result, "parsing_error", reason)
    end
  end

  defp validate_wraft_json(result, wraft_json) do
    case validate_global_file_wraft_json(wraft_json) do
      :ok -> result
      {:error, reason} -> add_error(result, "validation_error", reason)
    end
  end

  defp add_file_details(result, file) do
    file_details = FileHelper.get_global_file_info(file)
    Map.put(result, :file_details, file_details)
  end

  defp finalize_result(result) do
    result
    |> update_in([:errors], fn errors ->
      errors
      |> Enum.reverse()
      |> Enum.uniq_by(& &1.message)
    end)
    |> then(&{:ok, &1})
  end

  defp add_error(result, type, message) when is_list(message) do
    errors =
      Enum.map(message, fn reason ->
        %{type: type, message: reason}
      end)

    update_in(result, [:errors], &(errors ++ &1))
  end

  defp add_error(result, type, message) do
    error = %{type: type, message: message}
    update_in(result, [:errors], &[error | &1])
  end

  def validate_global_file_wraft_json(%{"metadata" => %{"type" => "frame"}} = wraft_json),
    do: FrameWraftJson.validate_json(wraft_json)

  def validate_global_file_wraft_json(
        %{"metadata" => %{"type" => "template_asset"}} = wraft_json
      ),
      do: TemplateAssets.validate_wraft_json(wraft_json)

  def validate_global_file_wraft_json(%{"metadata" => %{"type" => _}}),
    do: {:error, "Unsupported metadata type"}

  # def validate_global_asset(%{"file" => file, "type" => "frame"}),
  # do: FileHelper.validate_frame_file(file)
  #
  # def validate_global_asset(%{"file" => %{path: file_path} = file, "type" => "template_asset"}) do
  # with :ok <- TemplateAssets.validate_template_asset_file(file),
  #  {:ok, file_binary} <- File.read(file_path),
  #  {:ok, %{existing_items: _existing_items, missing_items: _missing_items} = result} <-
  #  TemplateAssets.pre_import_template(file_binary) do
  # {:ok, result}
  # end
  # end
end
