defmodule WraftDoc.GlobalFile do
  @moduledoc """
    Helper functions to files.
  """

  alias WraftDoc.Account.User
  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame
  alias WraftDoc.TemplateAssets
  alias WraftDoc.TemplateAssets.TemplateAsset
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

  # TODO import data template here instead of creating template asset
  def import_global_asset(current_user, %{"file" => file, "type" => "template_asset"} = params) do
    with :ok <- TemplateAssets.validate_template_asset_file(file),
         {:ok, params, _} <-
           TemplateAssets.process_template_asset(params, :file, file),
         {:ok, %TemplateAsset{} = template_asset} <-
           TemplateAssets.create_template_asset(current_user, params) do
      {:ok,
       %{
         view: TemplateAssetView,
         template: "template_asset.json",
         assigns: %{template_asset: template_asset}
       }}
    end
  end

  def import_global_asset(_, _), do: {:error, "Unsupported asset type"}

  def global_file_preview(%{path: file_path} = file) do
    with {:ok, file_binary} <- File.read(file_path),
         {:ok, wraft_json} <- FileHelper.get_wraft_json(file_binary),
         file_details <- FileHelper.get_global_file_info(file) do
      {:ok, %{meta: wraft_json, file_details: file_details}}
    end
  end
end
