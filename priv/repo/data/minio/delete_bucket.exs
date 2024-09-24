defmodule WraftDoc.Minio.DeleteBucket do
  @moduledoc """
  Delete minio bucket along with files

  mix run priv/repo/data/minio/delete_bucket.exs
  """
  require Logger
  alias WraftDoc.Minio.Utils

  @bucket_to_delete "wraft"

  # Check if bucket exist
  Logger.info("Checking if bucket #{@bucket_to_delete} exists")

  if Utils.bucket_exists?(@bucket_to_delete) do
    Logger.info("Deleting bucket #{@bucket_to_delete}")

    Logger.info("Deleting all objects in bucket #{@bucket_to_delete}")

    # list and delete all objects in the bucket
    @bucket_to_delete
    |> Utils.list_all_objects()
    |> Utils.delete_all_objects(@bucket_to_delete)

    Logger.info("All objects in bucket #{@bucket_to_delete} deleted")

    # Delete the bucket
    Utils.delete_bucket(@bucket_to_delete)

    Logger.info("Bucket #{@bucket_to_delete} deleted")
  else
    Logger.error("Bucket #{@bucket_to_delete} does not exist")
  end
end
