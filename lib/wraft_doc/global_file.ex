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

  @doc """
  Previews a global file by extracting its metadata and file details.
  """
  @spec global_file_preview(Plug.Upload.t()) ::
          {:ok, map()} | {:error, String.t()}
  def global_file_preview(%{path: file_path} = file) do
    with {:ok, _metadata} <- FileHelper.get_file_metadata(file),
         {:ok, file_binary} <- File.read(file_path),
         {:ok, wraft_json} <- FileHelper.get_wraft_json(file_binary),
         :ok <- validate_global_file_wraft_json(wraft_json),
         file_details <- FileHelper.get_global_file_info(file) do
      {:ok, %{meta: wraft_json, file_details: file_details}}
    end
  end

  def validate_global_file_wraft_json(%{"metadata" => %{"type" => "frame"}} = wraft_json),
    do: FrameWraftJson.validate_json(wraft_json)

  def validate_global_file_wraft_json(
        %{"metadata" => %{"type" => "template_asset"}} = wraft_json
      ),
      do: TemplateAssets.validate_wraft_json(wraft_json)

  def validate_global_asset(%{"file" => file, "type" => "frame"}),
    do: FileHelper.validate_frame_file(file)

  def validate_global_asset(%{"file" => %{path: file_path} = file, "type" => "template_asset"}) do
    with :ok <- TemplateAssets.validate_template_asset_file(file),
         {:ok, file_binary} <- File.read(file_path),
         {:ok, %{existing_items: _existing_items, missing_items: _missing_items} = result} <-
           TemplateAssets.pre_import_template(file_binary) do
      {:ok, result}
    end
  end
end
