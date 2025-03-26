defmodule WraftDoc.GlobalFile do
  @moduledoc """
    Helper functions to files.
  """

  alias WraftDoc.Account.User
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame

  @doc """
  Import zip asset by pattern matching asset type.
  """
  @spec import_global_asset(User.t(), Asset.t(), map()) ::
          {:ok, %{view: module(), template: String.t(), assigns: map()}} | {:error, String.t()}
  def import_global_asset(current_user, %{type: "frame"} = asset, params) do
    with {:ok, %Frame{} = frame} <- Frames.create_frame(current_user, asset, params) do
      {:ok,
       %{view: WraftDocWeb.Api.V1.FrameView, template: "create.json", assigns: %{frame: frame}}}
    end
  end

  def import_global_asset(_, _, _), do: {:error, "Unsupported asset type"}
end
