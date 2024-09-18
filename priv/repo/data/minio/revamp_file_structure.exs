defmodule WraftDoc.Minio.RevampFileStructure do
  @moduledoc """
   Reorder the file structure in object storage

    Script for revamping the file strucutre is as follows. You can run it as:

     mix run priv/repo/data/minio/revamp_file_structure.exs
  """

  require Logger
  alias WraftDoc.Minio.Utils

  @wraft_bucket "wraft"

  Logger.info("Revamp file path structure in object storage")

  # Add the public files to the bucket
  Utils.upload_default_public_files(@wraft_bucket)

  @wraft_bucket
  |> Utils.list_files("")
  |> Enum.each(&Utils.revamp_file_structure(@wraft_bucket, &1))

  # |> Enum.chunk_every(20)
  # |> Enum.each(&Task.await_many(&1, :infinity))

  Logger.info("Revamp file path structure in object storage completed")
end
