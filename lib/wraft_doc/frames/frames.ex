defmodule WraftDoc.Frames do
  @moduledoc """
  Module that handles frame related contexts.
  """
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Client.Minio
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Repo

  @doc """
  Lists all frames.
  """
  @spec list_frames(User.t(), map()) :: map()
  def list_frames(%{current_org_id: organisation_id}, params) do
    query =
      from(s in Frame,
        where: s.organisation_id == ^organisation_id,
        order_by: [desc: s.inserted_at]
      )

    Repo.paginate(query, params)
  end

  def list_frames(_, _), do: {:error, :fake}

  @doc """
  Retrieves a specific frame.
  """
  @spec get_frame(binary(), User.t()) :: Frame.t() | nil
  def get_frame(<<_::288>> = id, %{current_org_id: organisation_id}) do
    Repo.get_by(Frame, id: id, organisation_id: organisation_id)
  end

  def get_frame(_, _), do: nil

  @doc """
  Create a frame.
  """
  @spec create_frame(User.t(), map()) :: Frame.t() | {:error, Ecto.Changeset.t()}
  def create_frame(%{id: user_id, current_org_id: organisation_id}, attrs) do
    params =
      Map.merge(attrs, %{
        "organisation_id" => organisation_id,
        "creator_id" => user_id
      })

    Multi.new()
    |> Multi.insert(:frame, Frame.changeset(%Frame{}, params))
    |> Multi.update(:frame_file_upload, &Frame.file_changeset(&1.frame, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{frame_file_upload: frame}} -> {:ok, frame}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Update a frame.
  """
  @spec update_frame(Frame.t(), User.t(), map()) :: Frame.t() | {:error, Ecto.Changeset.t()}
  def update_frame(%Frame{} = frame, %{id: user_id, current_org_id: organisation_id}, attrs) do
    frame
    |> Frame.update_changeset(
      Map.merge(attrs, %{
        "organisation_id" => organisation_id,
        "creator_id" => user_id
      })
    )
    |> Repo.update()
  end

  @doc """
  Delete a frame.
  """
  @spec delete_frame(Frame.t()) :: {:ok, Frame.t()} | {:error, Ecto.Changeset.t()}
  def delete_frame(%Frame{id: frame_id, organisation_id: organisation_id, name: name} = frame) do
    case Minio.delete_file("organisations/#{organisation_id}/frames/#{frame_id}") do
      {:ok, _} ->
        frame_path =
          :wraft_doc
          |> :code.priv_dir()
          |> Path.join("slugs/#{name}")

        if File.exists?(frame_path) do
          File.rm_rf(frame_path)
        end

        Repo.delete(frame)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
